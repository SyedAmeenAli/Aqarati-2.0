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
  // The old Explore (banners, a grid of property types, people shortcuts) was removed on purpose: Explore is now
  // the one search page. These tests cover what replaced it.
  testWidgets('Explore is one search page: one input, a category row, no browse grid or banners', (t) async {
    t.view.physicalSize = const Size(393, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await settle(t);
    expect(find.byType(TextField), findsOneWidget);
    for (final label in ['All', 'Properties', 'Professionals', 'Services']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Browse by property type'), findsNothing);
    expect(find.text('Find your next place'), findsNothing);
    expect(find.text('Find people'), findsNothing);
  });

  testWidgets('every property type is still offered, as a filter inside the same page', (t) async {
    t.view.physicalSize = const Size(393, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app());
    await settle(t);
    await t.tap(find.text('Filters').first);
    await t.pumpAndSettle();
    expect(find.text('Property type'), findsWidgets);
    for (final label in ['Villa', 'Apartment', 'Warehouse']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(reached, '', reason: 'filtering did not navigate anywhere');
  });

  testWidgets('searching for a person or business stays on the same page and its card opens the profile', (t) async {
    t.view.physicalSize = const Size(393, 2400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    reached = '';
    await t.pumpWidget(app());
    await settle(t);
    await t.enterText(find.byType(TextField), 'Namaa');
    await settle(t);
    expect(reached, '', reason: 'typing does not send the user to another page');
    expect(find.text('Namaa Construction'), findsWidgets);
    await t.tap(find.text('Namaa Construction').first);
    await settle(t);
    expect(reached, startsWith('/business/'));
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
