import 'package:aqarati_app/core/localization/flow_strings.dart';
import 'package:aqarati_app/features/search/aq_filters.dart';
import 'package:aqarati_app/features/search/browse_taxonomy.dart';
import 'package:aqarati_app/features/workspace/aq_explore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

String reached = '';

Widget app({bool rtl = false}) => ProviderScope(
  child: MaterialApp.router(
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    routerConfig: GoRouter(routes: [
      GoRoute(path: '/', builder: (_, _) => const Scaffold(body: AQExploreScreen())),
      GoRoute(
        path: '/:p(.*)',
        builder: (_, s) {
          reached = s.uri.toString();
          return Scaffold(body: Text('AT ${s.uri}'));
        },
      ),
    ]),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('Explore offers every property type of all four markets, not only villas and apartments', (t) async {
    t.view.physicalSize = const Size(393, 5200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await settle(t);
    const f = FlowStrings.forTest(false);
    for (final cat in PropCategory.values) {
      expect(find.text(f.t(cat.key)), findsWidgets, reason: cat.name);
      for (final e in kBrowseTypes[cat]!) {
        expect(find.text(f.t('bt.${e.$1.name}')), findsWidgets, reason: '${cat.name}/${e.$1.name}');
      }
    }
    expect(find.text('Browse by property type'), findsOneWidget);
  });

  testWidgets('a type opens results for that market and type, not an unfiltered list', (t) async {
    t.view.physicalSize = const Size(393, 5200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await settle(t);
    await t.ensureVisible(find.text('Factory'));
    await t.tap(find.text('Factory'));
    await settle(t);
    expect(reached, '/properties/all?cat=industrial&types=industrial');
    await t.pumpWidget(app());
    await settle(t);
    await t.ensureVisible(find.text('Commercial Land'));
    await t.tap(find.text('Commercial Land'));
    await settle(t);
    expect(reached, '/properties/all?cat=commercial&types=commercialLand');
  });

  testWidgets('the people shortcuts reach their own directories', (t) async {
    t.view.physicalSize = const Size(393, 5200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final expected = {
      'Real estate agents': '/broker/list',
      'Trusted brokers': '/broker',
    };
    for (final e in expected.entries) {
      await t.pumpWidget(app());
      await settle(t);
      await t.ensureVisible(find.text(e.key));
      await t.tap(find.text(e.key));
      await settle(t);
      expect(reached, e.value, reason: e.key);
    }
  });

  for (final w in [320.0, 360.0, 412.0, 1024.0]) {
    testWidgets('Explore fits at ${w.toInt()} px, in Arabic too', (t) async {
      t.view.physicalSize = Size(w, 5200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      for (final rtl in [false, true]) {
        await t.pumpWidget(app(rtl: rtl));
        await settle(t);
        expect(t.takeException(), isNull, reason: 'rtl=$rtl');
      }
    });
  }
}
