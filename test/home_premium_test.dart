import 'package:aqarati_app/core/aq/aq_states.dart';
import 'package:aqarati_app/data/datasources/mock_business_data.dart';
import 'package:aqarati_app/data/datasources/mock_property_data.dart';
import 'package:aqarati_app/features/workspace/aq_cards.dart';
import 'package:aqarati_app/features/workspace/aq_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app(Widget child, {double width = 393, double scale = 1, TextDirection dir = TextDirection.ltr, ThemeMode mode = ThemeMode.light}) => ProviderScope(
  child: MaterialApp(
    themeMode: mode,
    theme: ThemeData(brightness: Brightness.light),
    darkTheme: ThemeData(brightness: Brightness.dark),
    locale: dir == TextDirection.rtl ? const Locale('ar') : const Locale('en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 852), textScaler: TextScaler.linear(scale)),
      child: Scaffold(body: child),
    ),
  ),
);

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  // Home must lay out without overflow at every width we ship, light and dark, English and Arabic,
  // and at large text. A thrown overflow is a test failure.
  for (final w in [320.0, 375.0, 430.0, 768.0, 1280.0]) {
    for (final dark in [false, true]) {
      for (final rtl in [false, true]) {
        testWidgets('Home lays out at ${w.toInt()} px dark=$dark rtl=$rtl', (t) async {
          await t.binding.setSurfaceSize(Size(w, 852));
          addTearDown(() => t.binding.setSurfaceSize(null));
          await t.pumpWidget(_app(const AQHomeScreen(), width: w, dir: rtl ? TextDirection.rtl : TextDirection.ltr, mode: dark ? ThemeMode.dark : ThemeMode.light));
          await _settle(t);
          expect(t.takeException(), isNull);
          expect(find.byType(AQSearchEntry), findsOneWidget);
          expect(find.byType(AQPropertyCard), findsNothing, reason: 'Shop Home is search, banner and services only');
          expect(find.byType(AQProfessionalCard), findsNothing);
        });
      }
    }
  }

  testWidgets('Home lays out at 200% text on a 320 px screen', (t) async {
    await t.binding.setSurfaceSize(const Size(320, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const AQHomeScreen(), width: 320, scale: 2));
    await _settle(t);
    expect(t.takeException(), isNull);
  });

  testWidgets('property card shows price, place, facts and an Enquire action; Save toggles', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final p = mockProperties.first;
    await t.pumpWidget(_app(Center(child: SizedBox(width: 280, child: AQPropertyCard(property: p)))));
    await _settle(t);
    expect(find.text(p.priceLabel), findsOneWidget);
    expect(find.text('Enquire'), findsOneWidget);
    expect(find.bySemanticsLabel('Save property'), findsOneWidget);
    await t.tap(find.bySemanticsLabel('Save property'));
    await t.pump();
    expect(find.bySemanticsLabel('Remove from saved'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('property card save and enquire targets are at least 48 px', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(Center(child: SizedBox(width: 280, child: AQPropertyCard(property: mockProperties.first)))));
    await _settle(t);
    final save = t.getSize(find.byType(AQSaveButton));
    expect(save.width, greaterThanOrEqualTo(48));
    expect(save.height, greaterThanOrEqualTo(48));
    final enquire = t.getSize(find.text('Enquire'));
    expect(enquire.height, greaterThan(0));
  });

  testWidgets('professional card shows name, what they do and a verified mark', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final b = mockBusinesses.firstWhere((b) => b.verification.isVerified);
    await t.pumpWidget(_app(Center(child: SizedBox(width: 260, child: AQProfessionalCard(business: b)))));
    await _settle(t);
    expect(find.text(b.name), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('empty, error and loading states build and the error offers a retry', (t) async {
    var retried = 0;
    await t.pumpWidget(_app(Column(children: [
      const AQEmptyState(title: 'Nothing here', body: 'Try again later'),
      AQErrorState(title: 'Broken', retryLabel: 'Try again', onRetry: () => retried++),
      const AQLoadingBlock(height: 40),
    ])));
    await t.pump();
    expect(find.text('Nothing here'), findsOneWidget);
    await t.tap(find.text('Try again'));
    expect(retried, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('search entry opens as one button with the hint as its label', (t) async {
    await t.pumpWidget(_app(const Padding(padding: EdgeInsets.all(24), child: AQSearchEntry(hint: 'Search homes'))));
    await t.pump();
    expect(find.bySemanticsLabel('Search homes'), findsOneWidget);
  });

  // Shop Home is the search bar, the sponsored banner and the six services, in that order, and nothing else.
  testWidgets('Home content is search, then services, with no hero, rails or greeting', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const AQHomeScreen()));
    await _settle(t);
    expect(find.byType(AQPropertyCard), findsNothing);
    expect(find.byType(AQProfessionalCard), findsNothing);
    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('Featured properties'), findsNothing);
    expect(find.text('Trusted professionals'), findsNothing);
    final search = t.getRect(find.byType(AQSearchEntry));
    final labels = ['Properties', 'Development', 'Interior & Exterior Designer', 'Construction Company', 'Maintenance', 'Loan Calculator'];
    var previousTop = search.bottom;
    for (final l in labels) {
      final r = t.getRect(find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('$l.') && w.properties.button == true));
      expect(r.top, greaterThanOrEqualTo(previousTop - 1), reason: '$l sits below the search bar and in order');
      previousTop = r.top;
    }
  });

  testWidgets('Home search entry and the Properties service open their existing routes', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 1400));
    addTearDown(() => t.binding.setSurfaceSize(null));
    final seen = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: AQHomeScreen())),
      GoRoute(path: '/search/start', builder: (_, _) { seen.add('/search/start'); return const Scaffold(); }),
      GoRoute(path: '/properties', builder: (_, _) { seen.add('/properties'); return const Scaffold(); }),
    ]);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
      ),
    ));
    await _settle(t);
    await t.tap(find.byType(AQSearchEntry));
    await t.pumpAndSettle();
    expect(seen, ['/search/start']);
    router.go('/');
    await _settle(t);
    final props = find.byWidgetPredicate((w) => w is Semantics && (w.properties.label ?? '').startsWith('Properties.') && w.properties.button == true);
    await t.tapAt(t.getCenter(props));
    await t.pumpAndSettle();
    expect(seen.last, '/properties');
  });
}
