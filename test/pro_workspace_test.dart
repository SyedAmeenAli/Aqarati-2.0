import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/core/localization/flow_strings.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

MeSession me(SignupPurpose p, [GrantState? g = GrantState.approved]) =>
    MeSession(account: AccountState.active, purpose: p, grant: g);

const roles = {
  SignupPurpose.propertyDevelopmentCompany: HomeRole.developer,
  SignupPurpose.constructionCompany: HomeRole.construction,
  SignupPurpose.buildingArchitecture: HomeRole.architecture,
  SignupPurpose.interiorExteriorDesign: HomeRole.interiorExterior,
};

Widget app(MeSession s, {String start = '/pro', bool dark = false, bool rtl = false, double scale = 1}) => ProviderScope(
  overrides: [meProvider.overrideWith((ref) async => s)],
  child: MaterialApp.router(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
    routerConfig: GoRouter(
      initialLocation: start,
      routes: [
        ShellRoute(
          builder: (c, st, child) => ProShell(child: child),
          routes: [
            GoRoute(path: '/pro', builder: (_, _) => const Text('PRO HOME')),
            GoRoute(path: '/pro/more', builder: (_, _) => const ProMoreScreen()),
            for (final p in ['/app/account/workspace/projects', '/app/account/workspace/leads', '/app/account/workspace/profile', '/app/account/workspace/portfolio', '/app/account/workspace/engagements', '/app/account/workspace', '/pro/units', '/pro/projects', '/pro/services', '/pro/analytics'])
              GoRoute(path: p, builder: (_, st) => Text('STUB ${st.uri.path}')),
          ],
        ),
        GoRoute(path: '/app/home', builder: (_, _) => const Text('CUSTOMER HOME')),
        GoRoute(path: '/:p(.*)', builder: (_, st) => Text('AT ${st.uri}')),
      ],
    ),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void phone(WidgetTester t, {double w = 393, double h = 1400}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('navigation per role (pure)', () {
    test('each role has six tabs, its own words and routes, and Analytics as a tab', () {
      final labels = <String>{};
      for (final r in roles.values) {
        final tabs = proTabsFor(r);
        expect(tabs.length, 6, reason: '$r');
        expect(tabs.first.route, '/pro');
        expect(tabs.last.route, '/pro/more');
        expect(tabs[4].route, '/pro/analytics', reason: '$r has Analytics as its fifth tab');
        labels.add(tabs.map((t) => t.labelKey).join('|'));
      }
      expect(labels.length, 4, reason: 'every role has its own tab set');
      List<String> keys(HomeRole r) => proTabsFor(r).map((t) => t.labelKey).toList();
      expect(keys(HomeRole.developer), ['pn.overview', 'pn.projects', 'pn.units', 'pn.enquiries', 'an.title', 'pn.company']);
      expect(keys(HomeRole.construction), ['pn.overview', 'pn.projects', 'pn.requests', 'pn.services', 'an.title', 'pn.company']);
      expect(keys(HomeRole.architecture), ['pn.studio', 'pn.portfolio', 'pn.projects', 'pn.enquiries', 'an.title', 'pn.profile']);
      expect(keys(HomeRole.interiorExterior), ['pn.studio', 'pn.portfolio', 'pn.services', 'pn.engagements', 'an.title', 'pn.profile']);
      expect(proTabsFor(HomeRole.buyer), isEmpty);
      expect(proTabsFor(HomeRole.agent), isEmpty);
    });

    test('on a phone each role shows four day-to-day destinations plus More, and nothing is lost', () {
      List<String> keys(HomeRole r) => proTabsFor(r, compact: true).map((t) => t.labelKey).toList();
      expect(keys(HomeRole.developer), ['pn.overview', 'pn.projects', 'pn.enquiries', 'pn.units', 'pn.more']);
      expect(keys(HomeRole.construction), ['pn.overview', 'pn.projects', 'pn.requests', 'pn.services', 'pn.more']);
      expect(keys(HomeRole.architecture), ['pn.studio', 'pn.portfolio', 'pn.projects', 'pn.enquiries', 'pn.more']);
      expect(keys(HomeRole.interiorExterior), ['pn.studio', 'pn.portfolio', 'pn.services', 'pn.engagements', 'pn.more']);
      for (final r in roles.values) {
        final compact = proTabsFor(r, compact: true);
        final full = proTabsFor(r);
        expect(compact.length, 5);
        expect(compact.last.route, '/pro/more');
        // Every full destination is either a phone tab or reached under More (selected there).
        for (final t in full) {
          final onBar = compact.take(4).any((c) => c.route == t.route);
          expect(onBar || proTabIndex(compact, t.route) == 4, isTrue, reason: '${r.name} ${t.labelKey} stays reachable');
        }
        expect(proTabIndex(compact, '/pro/analytics'), 4, reason: 'Analytics is selected under More');
        expect(proTabIndex(compact, '/app/account/workspace/profile'), 4);
      }
    });

    test('a location selects the tab it belongs to', () {
      final dev = proTabsFor(HomeRole.developer);
      expect(proTabIndex(dev, '/pro'), 0);
      expect(proTabIndex(dev, '/app/account/workspace/projects'), 1);
      expect(proTabIndex(dev, '/workspace/projects/new'), 1);
      expect(proTabIndex(dev, '/pro/units'), 2);
      expect(proTabIndex(dev, '/app/account/workspace/leads'), 3);
      expect(proTabIndex(dev, '/workspace/leads/L1'), 3);
      expect(proTabIndex(dev, '/pro/analytics'), 4);
      expect(proTabIndex(dev, '/app/account/workspace/profile'), 5);
      expect(proTabIndex(dev, '/app/account/workspace/reviews'), 5);
      expect(proTabIndex(dev, '/pro/settings'), 5);
      expect(proTabIndex(dev, '/pro/more'), 5);
      final con = proTabsFor(HomeRole.construction);
      expect(proTabIndex(con, '/pro/projects'), 1);
      expect(proTabIndex(con, '/workspace/leads/L1'), 2);
      expect(proTabIndex(con, '/pro/services'), 3);
      expect(proTabIndex(con, '/app/account/workspace/portfolio'), 5);
      final arch = proTabsFor(HomeRole.architecture);
      expect(proTabIndex(arch, '/app/account/workspace/portfolio'), 1);
      expect(proTabIndex(arch, '/pro/projects'), 2);
      expect(proTabIndex(arch, '/app/account/workspace/leads'), 3);
      expect(proTabIndex(arch, '/workspace/engagements/E1'), 5);
      final int = proTabsFor(HomeRole.interiorExterior);
      expect(proTabIndex(int, '/pro/services'), 2);
      expect(proTabIndex(int, '/app/account/workspace/engagements'), 3);
      expect(proTabIndex(int, '/workspace/engagements/E1'), 3);
    });
  });

  group('professional workspace', () {
    for (final e in roles.entries) {
      testWidgets('${e.key.name}: four role tabs plus More and none of the customer or agent tabs', (t) async {
        phone(t);
        await t.pumpWidget(app(me(e.key)));
        await settle(t);
        expect(find.text('PRO HOME'), findsOneWidget);
        const f = FlowStrings.forTest(false);
        for (final tab in proTabsFor(e.value, compact: true)) {
          expect(find.text(f.t(tab.labelKey)), findsWidgets, reason: tab.labelKey);
        }
        for (final s in ['Explore', 'Activity', 'Account', 'Contacts', 'Calendar']) {
          expect(find.text(s), findsNothing, reason: 'foreign tab $s');
        }
      });
    }

    testWidgets('the four roles show four different navigation bars', (t) async {
      phone(t);
      final seen = <String>{};
      for (final e in roles.entries) {
        await t.pumpWidget(app(me(e.key)));
        await settle(t);
        const f = FlowStrings.forTest(false);
        seen.add(proTabsFor(e.value, compact: true).map((x) => f.t(x.labelKey)).join(','));
      }
      expect(seen.length, 4);
    });

    testWidgets('tapping a tab opens that role\'s page', (t) async {
      phone(t);
      await t.pumpWidget(app(me(SignupPurpose.buildingArchitecture)));
      await settle(t);
      await t.tap(find.text('Portfolio').last);
      await settle(t);
      expect(find.text('STUB /app/account/workspace/portfolio'), findsOneWidget);
      await t.tap(find.text('Projects').last);
      await settle(t);
      expect(find.text('STUB /pro/projects'), findsOneWidget);
      await t.tap(find.text('Enquiries').last);
      await settle(t);
      expect(find.text('STUB /app/account/workspace/leads'), findsOneWidget);
    });

    testWidgets('a shopper, a guest-like agent and a pending business are refused', (t) async {
      phone(t);
      for (final s in [
        me(SignupPurpose.userToShop, null),
        me(SignupPurpose.realEstateAgent),
        me(SignupPurpose.constructionCompany, GrantState.pendingVerification),
      ]) {
        await t.pumpWidget(app(s));
        await settle(t);
        expect(find.text('PRO HOME'), findsNothing);
        expect(find.text('Business workspace only'), findsWidgets);
      }
    });

    testWidgets('More leads to reviews and status, back to the shopper app and sign out', (t) async {
      phone(t);
      await t.pumpWidget(app(me(SignupPurpose.interiorExteriorDesign), start: '/pro/more'));
      await settle(t);
      for (final s in ['Reviews of your business', 'Verification status', 'Browse as a customer', 'Sign out']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      await t.tap(find.text('Browse as a customer'));
      await settle(t);
      expect(find.text('AT /app/explore'), findsOneWidget);
    });

    for (final w in [320.0, 360.0, 412.0, 430.0, 1280.0]) {
      testWidgets('shell fits at ${w.toInt()} px, dark, RTL and large text', (t) async {
        phone(t, w: w, h: w > 900 ? 900 : 800);
        for (final e in roles.keys) {
          for (final path in ['/pro', '/pro/more']) {
            await t.pumpWidget(app(me(e), start: path));
            await settle(t);
            expect(t.takeException(), isNull, reason: '${e.name} $path @ $w');
            await t.pumpWidget(app(me(e), start: path, dark: true, rtl: true, scale: 1.6));
            await settle(t);
            expect(t.takeException(), isNull, reason: '${e.name} $path @ $w dark rtl');
          }
        }
      });
    }
  });
}
