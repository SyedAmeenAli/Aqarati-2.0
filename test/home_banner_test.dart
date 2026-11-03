import 'dart:io';

import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/ads/ad_models.dart';
import 'package:aqarati_app/features/ads/ad_repository.dart';
import 'package:aqarati_app/features/ads/sponsored_banner.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/workspace/aq_explore.dart';
import 'package:aqarati_app/features/workspace/aq_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

AdDraft _ad(String name, String headline) => AdDraft(
  sponsor: name,
  headline: headline,
  body: 'Modern living, timeless surroundings.',
  cta: 'Learn more',
  destination: '/app/explore',
  imageRef: 'assets/location/11_Muscat_skyline_and_mountains.jpg',
);

Widget _app(Widget child, DemoAdRepository repo, {double width = 393}) =>
    ProviderScope(
      overrides: [
        meProvider.overrideWith(
          (ref) async => const MeSession(
            account: AccountState.active,
            purpose: SignupPurpose.userToShop,
          ),
        ),
        adRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 844)),
          child: Scaffold(body: child),
        ),
      ),
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  testWidgets('Home shows one compact banner, above the six services', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final repo = DemoAdRepository(latency: Duration.zero)
      ..debugAdd(_ad('Acme', 'Discover homes in Oman'));
    await t.pumpWidget(_app(const AQHomeScreen(), repo));
    await _settle(t);
    expect(find.byType(SponsoredBannerView), findsOneWidget);
    final banner = t.getRect(find.byType(SponsoredBannerView));
    expect(banner.height, kSponsoredBannerHeight);
    expect(banner.height, inInclusiveRange(80, 100));
    final properties = find.byWidgetPredicate(
      (w) => w is Semantics && (w.properties.label ?? '').startsWith('Properties.') && w.properties.button == true,
    );
    expect(properties, findsOneWidget);
    expect(t.getRect(properties).top, greaterThan(banner.bottom - 1), reason: 'the banner sits above the services');
    // The premium Home pass puts one search entry under the greeting, above the banner; it opens the same search.
    expect(find.byType(AQSearchEntry), findsOneWidget, reason: 'Home carries one search entry');
    expect(t.getRect(find.byType(AQSearchEntry)).bottom, lessThan(banner.top + 1), reason: 'search sits above the banner');
  });

  for (final w in [320.0, 360.0, 390.0, 412.0, 430.0]) {
    testWidgets('the banner fits at ${w.toInt()} px', (t) async {
      await t.binding.setSurfaceSize(Size(w, 844));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final repo = DemoAdRepository(latency: Duration.zero)
        ..debugAdd(
          _ad('A sponsor with a long name', 'A very long campaign title here'),
        );
      await t.pumpWidget(_app(const AQHomeScreen(), repo, width: w));
      await _settle(t);
      expect(find.byType(SponsoredBannerView), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('rotation keeps the layout still', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final repo = DemoAdRepository(latency: Duration.zero)
      ..debugAdd(_ad('One', 'First title'))
      ..debugAdd(_ad('Two', 'Second title that is much longer than the first'));
    await t.pumpWidget(_app(const AQHomeScreen(), repo));
    await _settle(t);
    final heroBefore = t.getTopLeft(find.textContaining('looking for today'));
    expect(find.text('First title'), findsOneWidget);
    await t.pump(kAdRotation + const Duration(milliseconds: 700));
    expect(
      find.text('Second title that is much longer than the first'),
      findsOneWidget,
    );
    expect(t.getTopLeft(find.textContaining('looking for today')), heroBefore);
  });

  testWidgets('no eligible ad: no banner and no blank space', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      _app(const AQHomeScreen(), DemoAdRepository(latency: Duration.zero)),
    );
    await _settle(t);
    expect(find.byType(SponsoredBannerView), findsNothing);
    final without = t.getTopLeft(find.text('Development')).dy;
    final repo = DemoAdRepository(latency: Duration.zero)
      ..debugAdd(_ad('Acme', 'Offer'));
    await t.pumpWidget(_app(const AQHomeScreen(), repo));
    await _settle(t);
    final withAd = t.getTopLeft(find.text('Development')).dy;
    expect(withAd - without, greaterThan(kSponsoredBannerHeight - 1));
  });

  testWidgets('Explore does not show the banner', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final repo = DemoAdRepository(latency: Duration.zero)
      ..debugAdd(_ad('Acme', 'Offer'));
    await t.pumpWidget(_app(const AQExploreScreen(), repo));
    await _settle(t);
    expect(find.byType(SponsoredBannerView), findsNothing);
  });

  test('only the six Home screens mount the banner; nothing mounts it app-wide', () {
    final users = <String>[];
    for (final e in Directory('lib').listSync(recursive: true)) {
      if (e is! File || !e.path.endsWith('.dart')) continue;
      final src = e.readAsStringSync();
      if (src.contains('SponsoredBannerSlot(') &&
          !e.path.endsWith('sponsored_banner.dart')) {
        users.add(e.path.replaceAll('\\', '/'));
      }
    }
    users.sort();
    expect(users, [
      'lib/features/agent/agent_screens.dart',
      'lib/features/role_home/home_construction.dart',
      'lib/features/role_home/home_developer.dart',
      'lib/features/role_home/home_studio.dart', // architecture and interior
      'lib/features/workspace/aq_home.dart',
    ]);
    expect(
      File('lib/main.dart').readAsStringSync().contains('SponsoredBanner'),
      isFalse,
    );
    // The admin console previews with the view; it never mounts the live slot.
    for (final e in Directory('lib/admin').listSync(recursive: true)) {
      if (e is File && e.path.endsWith('.dart')) {
        expect(e.readAsStringSync().contains('SponsoredBannerSlot'), isFalse);
      }
    }
  });
}
