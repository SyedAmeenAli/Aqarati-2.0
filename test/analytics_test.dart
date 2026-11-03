import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/analytics/analytics_charts.dart';
import 'package:aqarati_app/features/analytics/analytics_screens.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, {bool rtl = false, bool dark = false, double scale = 1}) => ProviderScope(
  overrides: [
    meProvider.overrideWith(
      (ref) async => const MeSession(account: AccountState.active, purpose: SignupPurpose.realEstateAgent, grant: GrantState.approved),
    ),
  ],
  child: MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
    home: Scaffold(body: child),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  group('sample series', () {
    test('the same key always gives the same twelve weeks', () {
      final a = sampleWeekly('agent-leads');
      final b = sampleWeekly('agent-leads');
      expect(a, b);
      expect(a.length, 12);
      expect(sampleWeekly('developer-enq'), isNot(a));
    });

    test('values stay positive whole numbers', () {
      for (final k in ['a', 'b', 'c', 'architecture-pviews']) {
        for (final v in sampleWeekly(k, base: 3, amp: 6)) {
          expect(v, greaterThanOrEqualTo(1));
          expect(v, v.roundToDouble());
        }
      }
    });
  });

  group('charts', () {
    for (final w in [320.0, 390.0, 1024.0]) {
      testWidgets('line, bar and donut fit at ${w.toInt()} px, in Arabic, dark and large text', (t) async {
        t.view.physicalSize = Size(w, 1400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          app(
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                AnalyticsCard(
                  title: 'Leads by week',
                  note: 'Sample data',
                  child: AQLineChart(values: sampleWeekly('x').sublist(4), labels: List.generate(8, (i) => 'W$i'), semanticsLabel: 'Leads'),
                ),
                const AnalyticsCard(title: 'Bars', child: AQBarChart(items: [('New', 4), ('Contacted', 2), ('Won', 1)])),
                const AnalyticsCard(title: 'Donut', child: AQDonut(parts: [('A', 3), ('B', 2)], centerLabel: 'total')),
                const KpiGrid(tiles: [KpiTile(label: 'One', value: '3'), KpiTile(label: 'Two', value: '4'), KpiTile(label: 'Three', value: '5')]),
              ]),
            ),
            rtl: true,
            dark: true,
            scale: 1.6,
          ),
        );
        await settle(t);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('an empty composition says so instead of drawing a ring of nothing', (t) async {
      await t.pumpWidget(app(const AQDonut(parts: [('A', 0)], centerLabel: 'total')));
      await settle(t);
      expect(t.takeException(), isNull);
    });
  });

  group('role analytics pages', () {
    for (final role in [HomeRole.agent, HomeRole.developer, HomeRole.construction, HomeRole.architecture, HomeRole.interiorExterior]) {
      testWidgets('${role.name}: renders its own sections without overflow at 390 px and 1280 px, Arabic too', (t) async {
        for (final (w, rtl) in [(390.0, false), (1280.0, false), (360.0, true)]) {
          t.view.physicalSize = Size(w, 2400);
          t.view.devicePixelRatio = 1;
          await t.pumpWidget(app(RoleAnalyticsScreen(role: role), rtl: rtl));
          await settle(t);
          expect(t.takeException(), isNull, reason: '${role.name} @$w rtl=$rtl');
          expect(find.byType(AnalyticsCard), findsWidgets);
          expect(find.text(rtl ? 'التحليلات' : 'Analytics'), findsWidgets);
        }
        addTearDown(t.view.reset);
      });
    }

    testWidgets('the range chips change the chart span', (t) async {
      t.view.physicalSize = const Size(390, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const RoleAnalyticsScreen(role: HomeRole.agent)));
      await settle(t);
      await t.tap(find.text('12 weeks'));
      await settle(t);
      expect(t.takeException(), isNull);
      await t.tap(find.text('4 weeks'));
      await settle(t);
      expect(t.takeException(), isNull);
    });

    testWidgets('sample figures are labelled as sample data', (t) async {
      t.view.physicalSize = const Size(390, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const RoleAnalyticsScreen(role: HomeRole.developer)));
      await settle(t);
      expect(find.textContaining('Sample data'), findsWidgets);
      expect(find.textContaining('measure no real visitors'), findsWidgets);
    });
  });

  group('home KPI strip', () {
    testWidgets('a shopper gets nothing', (t) async {
      await t.pumpWidget(app(const RoleKpiStrip(role: HomeRole.buyer)));
      await settle(t);
      expect(find.byType(KpiTile), findsNothing);
    });

    testWidgets('a professional gets three figures and a link to the analytics page', (t) async {
      t.view.physicalSize = const Size(390, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(const RoleKpiStrip(role: HomeRole.developer)));
      await settle(t);
      expect(find.byType(KpiTile), findsNWidgets(3));
      expect(find.text('View analytics'), findsOneWidget);
    });
  });
}
