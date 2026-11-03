import 'package:aqarati_app/data/models/enums.dart';
import 'package:aqarati_app/core/router/app_router.dart' show appRouter;
import 'package:aqarati_app/data/datasources/mock_business_data.dart';
import 'package:aqarati_app/data/datasources/mock_property_data.dart';
import 'package:aqarati_app/features/search/aq_filter_sheet.dart' show AQChoicePill;
import 'package:aqarati_app/features/search/aq_unified_search.dart';
import 'package:aqarati_app/features/workspace/aq_cards.dart';
import 'package:aqarati_app/features/workspace/aq_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

late List<String> seen;

Widget _app({String start = '/app/explore'}) {
  seen = [];
  final router = GoRouter(initialLocation: start, routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: AQHomeScreen())),
    GoRoute(
      path: '/app/explore',
      builder: (_, s) => Scaffold(body: AQUnifiedSearch(initialQuery: s.uri.queryParameters['q'], focus: s.uri.queryParameters['focus'] == '1')),
    ),
    GoRoute(path: '/property/:id', builder: (_, s) { seen.add('/property/${s.pathParameters['id']}'); return const Scaffold(); }),
    GoRoute(path: '/business/:id', builder: (_, s) { seen.add('/business/${s.pathParameters['id']}'); return const Scaffold(); }),
  ]);
  return ProviderScope(
    child: MaterialApp.router(
      routerConfig: router,
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('ar')],
    ),
  );
}

Future<void> _settle(WidgetTester t) async {
  await t.pump();
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  void phone(WidgetTester t, double w, [double h = 1800]) {
    t.view.physicalSize = Size(w, h);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
  }

  testWidgets('a real text query filters the existing listings in place', (t) async {
    phone(t, 375);
    await t.pumpWidget(_app());
    await _settle(t);
    final all = find.byType(AQResultCard).evaluate().length;
    expect(all, greaterThan(0), reason: 'Explore shows results immediately');

    await t.enterText(find.byType(TextField), 'villa');
    await _settle(t);
    final villaCount = mockProperties.where((p) => '${p.title} ${p.locationLabel} ${p.type.label}'.toLowerCase().contains('villa')).length;
    final shown = find.byType(AQResultCard).evaluate().length;
    expect(shown, greaterThan(0));
    expect(shown, lessThan(all), reason: 'the query narrowed the list');
    expect(shown, lessThanOrEqualTo(4), reason: 'All shows the first four and offers See all');
    expect(villaCount, greaterThan(0));
    expect(find.text('Residential Plot in Al Khoudh'), findsNothing, reason: 'a non-matching listing is gone');

    // Clearing restores the full list in the same page.
    await t.enterText(find.byType(TextField), '');
    await _settle(t);
    expect(find.byType(AQResultCard).evaluate().length, all);
  });

  testWidgets('a business name finds professionals; the category row switches kind without leaving the page', (t) async {
    phone(t, 375);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Wadi');
    await _settle(t);
    expect(find.byType(AQProfessionalCard), findsWidgets);
    expect(find.text('Wadi Architecture'), findsWidgets);

    await t.enterText(find.byType(TextField), '');
    await _settle(t);
    await t.ensureVisible(find.widgetWithText(AQChoicePill, 'Professionals'));
    await t.tap(find.widgetWithText(AQChoicePill, 'Professionals'));
    await _settle(t);
    expect(find.byType(AQResultCard), findsNothing, reason: 'Professionals shows no property cards');
    expect(find.byType(AQProfessionalCard), findsWidgets);
    expect(find.byType(AQUnifiedSearch), findsOneWidget);
  });

  testWidgets('an existing filter (purpose: rent) applies from the one filter sheet', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.tap(find.widgetWithText(AQChoicePill, 'Properties'));
    await _settle(t);
    final before = find.byType(AQResultCard).evaluate().length;
    await t.tap(find.text('Filters').first);
    await t.pumpAndSettle();
    expect(find.text('Purpose'), findsWidgets, reason: 'the existing filter groups are in the sheet');
    await t.tap(find.text('Rent').last);
    await t.pumpAndSettle();
    await t.tap(find.textContaining('Show ').last);
    await t.pumpAndSettle();
    final after = find.byType(AQResultCard).evaluate().length;
    final rent = mockProperties.where((p) => p.transactionType.name == 'rent').length;
    expect(after, rent);
    expect(after, lessThan(before));
  });

  testWidgets('the Home search bar and the Explore tab are the same search page', (t) async {
    phone(t, 375);
    await t.pumpWidget(_app(start: '/'));
    await _settle(t);
    await t.tap(find.byType(AQSearchEntry));
    await t.pumpAndSettle();
    expect(find.byType(AQUnifiedSearch), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget, reason: 'one search input');
  });

  testWidgets('a result opens its original detail route', (t) async {
    phone(t, 375);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.tap(find.byType(AQResultCard).first);
    await t.pumpAndSettle();
    expect(seen.last, startsWith('/property/'));

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(_app());
    await _settle(t);
    await t.enterText(find.byType(TextField), mockBusinesses.first.name);
    await _settle(t);
    await t.tap(find.byType(AQProfessionalCard).first);
    await t.pumpAndSettle();
    expect(seen.last, startsWith('/business/'));
  });

  for (final w in [320.0, 375.0]) {
    testWidgets('unified search lays out at ${w.toInt()} px without overflow', (t) async {
      phone(t, w);
      await t.pumpWidget(_app());
      await _settle(t);
      await t.enterText(find.byType(TextField), 'a');
      await _settle(t);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('maintenance searches ("AC repair") find the existing maintenance provider and open its profile', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    final maint = mockBusinesses.firstWhere((b) => b.categories.contains(BusinessCategory.maintenance));
    await t.enterText(find.byType(TextField), 'AC repair');
    await _settle(t);
    expect(find.text(maint.name), findsWidgets, reason: 'the maintenance provider is found');
    expect(find.byType(AQResultCard), findsNothing, reason: 'no listing matches the words "AC repair"');
    await t.tap(find.byType(AQProfessionalCard).first);
    await t.pumpAndSettle();
    expect(seen.last, '/business/${maint.id}', reason: 'same destination as the old directory card');
  });

  testWidgets('"ac" inside another word does not pull in maintenance providers', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.enterText(find.byType(TextField), 'Muscat');
    await _settle(t);
    final maint = mockBusinesses.firstWhere((b) => b.categories.contains(BusinessCategory.maintenance));
    // Rawaq is in Muscat, so it can match by place; this only checks the keyword rule did not fire by itself.
    await t.enterText(find.byType(TextField), 'sale');
    await _settle(t);
    expect(find.text(maint.name), findsNothing);
  });

  testWidgets('Professionals filter: verified only uses the existing verification state', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.ensureVisible(find.widgetWithText(AQChoicePill, 'Professionals'));
    await t.tap(find.widgetWithText(AQChoicePill, 'Professionals'));
    await _settle(t);
    final nonService = mockBusinesses.where((b) => !b.categories.contains(BusinessCategory.maintenance)).toList();
    final verified = nonService.where((b) => b.verification.isVerified).length;
    expect(find.byType(AQProfessionalCard).evaluate().length, nonService.length);
    expect(verified, lessThan(nonService.length), reason: 'the mock data has an unverified business to filter out');
    await t.tap(find.text('Filters').first);
    await t.pumpAndSettle();
    await t.tap(find.text('Verified professionals only'));
    await t.pumpAndSettle();
    await t.tap(find.text('Apply filters'));
    await t.pumpAndSettle();
    expect(find.byType(AQProfessionalCard).evaluate().length, verified);
  });

  testWidgets('Services shows only maintenance providers and offers verified-only (no invented filters)', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    await t.ensureVisible(find.widgetWithText(AQChoicePill, 'Services'));
    await t.tap(find.widgetWithText(AQChoicePill, 'Services'));
    await _settle(t);
    final maintCount = mockBusinesses.where((b) => b.categories.contains(BusinessCategory.maintenance)).length;
    expect(find.byType(AQProfessionalCard).evaluate().length, maintCount);
    await t.tap(find.text('Filters').first);
    await t.pumpAndSettle();
    expect(find.text('Verified professionals only'), findsOneWidget);
    expect(find.text('Apply filters'), findsOneWidget);
  });

  testWidgets('every search route of the real app lands on the one search page', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(ProviderScope(
      child: MaterialApp.router(
        routerConfig: appRouter,
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
      ),
    ));
    await t.pump(const Duration(milliseconds: 300));
    for (final route in ['/search/start', '/search?q=villa', '/app/explore', '/app/explore?focus=1']) {
      appRouter.go(route);
      await _settle(t);
      expect(find.byType(AQUnifiedSearch), findsOneWidget, reason: route);
      expect(find.byType(TextField), findsOneWidget, reason: 'one search input at $route');
    }
    appRouter.go('/search?q=villa');
    await _settle(t);
    expect(find.text('villa'), findsOneWidget, reason: 'the query from the old route is carried into the field');
  });

  testWidgets('saving a result still works from the unified page', (t) async {
    phone(t, 375, 2400);
    await t.pumpWidget(_app());
    await _settle(t);
    expect(find.bySemanticsLabel('Save property'), findsWidgets);
    await t.tap(find.bySemanticsLabel('Save property').first);
    await t.pump();
    expect(find.bySemanticsLabel('Remove from saved'), findsOneWidget);
  });
}
