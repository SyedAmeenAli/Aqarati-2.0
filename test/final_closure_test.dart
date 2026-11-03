import 'package:aqarati_app/core/localization/viewing_strings.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/datasources/mock_property_data.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/features/broker/broker_repository.dart';
import 'package:aqarati_app/features/compare/compare_screen.dart';
import 'package:aqarati_app/features/flow/screens/verification_onboarding_screens.dart';
import 'package:aqarati_app/features/property/property_detail_screen.dart';
import 'package:aqarati_app/features/viewing/screens/viewing_schedule_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The final visual-defect closure: desktop property details, phone compare, the two booking steps,
/// the broker directory names, and the signed-out redirect for the document screen.
Widget _app(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: child,
      ),
    );

Future<void> _settle(WidgetTester t, [int n = 8]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

void _size(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('Property Details at desktop width', () {
    testWidgets('gallery and the key facts sit side by side, and the pinned actions remain', (t) async {
      _size(t, 1280, 900);
      await t.pumpWidget(_app(PropertyDetailScreen(propertyId: mockProperties.first.id)));
      await _settle(t);
      final gallery = t.getRect(find.byType(PageView).first);
      final title = t.getRect(find.textContaining(mockProperties.first.title).first);
      expect(gallery.width, greaterThan(560), reason: 'the gallery gets real width on desktop');
      expect(title.left, greaterThan(gallery.right - 1), reason: 'the title block is beside the gallery, not under it');
      expect(find.text('Book viewing'), findsWidgets);
      expect(find.text('Enquire'), findsWidgets);
      expect(t.takeException(), isNull);
    });

    testWidgets('a phone keeps the single column', (t) async {
      _size(t, 390, 844);
      await t.pumpWidget(_app(PropertyDetailScreen(propertyId: mockProperties.first.id)));
      await _settle(t);
      final gallery = t.getRect(find.byType(PageView).first);
      final title = t.getRect(find.textContaining(mockProperties.first.title).first);
      expect(title.top, greaterThanOrEqualTo(gallery.bottom - 1));
      expect(t.takeException(), isNull);
    });
  });

  group('Compare', () {
    final ids = mockProperties.take(3).map((p) => p.id).toList();

    testWidgets('a narrow phone shows lettered cards and a table with every attribute', (t) async {
      _size(t, 320, 800);
      await t.pumpWidget(_app(CompareScreen(propertyIds: ids)));
      await _settle(t);
      expect(find.text('View property'), findsNWidgets(3));
      for (final label in ['Price', 'Type', 'Bedrooms', 'Bathrooms', 'Area', 'Parking', 'Amenities']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      for (final l in ['A', 'B', 'C']) {
        expect(find.text(l), findsWidgets, reason: 'column $l');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('a tablet lays the properties out in equal columns without sideways scrolling', (t) async {
      _size(t, 768, 1024);
      await t.pumpWidget(_app(CompareScreen(propertyIds: ids)));
      await _settle(t);
      expect(find.text('View property'), findsNWidgets(3));
      final rects = [for (final e in find.text('View property').evaluate()) t.getRect(find.byWidget(e.widget))];
      for (final r in rects) {
        expect(r.right, lessThanOrEqualTo(768));
        expect(r.left, greaterThanOrEqualTo(0));
      }
      expect(t.takeException(), isNull);
    });
  });

  group('Viewing booking steps', () {
    testWidgets('step 1 asks for a date only; step 2 asks for a time only', (t) async {
      _size(t, 390, 844);
      await t.pumpWidget(_app(const ViewingAvailabilityScreen(propertyId: 'p1')));
      await _settle(t, 10);
      expect(find.text('Choose a date'), findsWidgets);
      expect(find.textContaining('Step 1 of 3'), findsOneWidget);
      expect(find.text('Choose a time'), findsOneWidget, reason: 'only the continue action mentions the time step');
      expect(find.text('Morning'), findsNothing, reason: 'times belong to step 2');

      await t.pumpWidget(_app(const ViewingSlotScreen(propertyId: 'p1')));
      await _settle(t, 10);
      expect(find.textContaining('Step 2 of 3'), findsOneWidget);
      expect(find.text('Change date'), findsOneWidget);
      expect(find.text('Review request'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    test('every step string has an Arabic pair', () {
      const en = ViewingStrings.forTest(false), ar = ViewingStrings.forTest(true);
      for (final k in ViewingStrings.keys.where((k) => k.startsWith('vw.s1.') || k.startsWith('vw.s2.') || k.startsWith('vw.short.') || k.startsWith('vw.step'))) {
        expect(ar.t(k).trim(), isNotEmpty, reason: k);
        expect(ar.t(k), isNot(en.t(k)), reason: '$k has a distinct Arabic string');
      }
    });
  });

  group('Broker directory names', () {
    test('customer-facing names are polished and clearly fictional; stable ids are unchanged', () {
      expect(kQaSampleBrokers.map((b) => b.id), ['qa-broker-1', 'qa-broker-2']);
      for (final b in kQaSampleBrokers) {
        expect(b.name.toLowerCase(), isNot(contains('qa ')));
        expect(b.name.toLowerCase(), contains('sample'));
        expect(b.about.toLowerCase(), isNot(contains('review-build')));
      }
    });
  });

  group('Signed-out visit to a protected onboarding screen', () {
    testWidgets('redirects to sign-in carrying the destination, with no error frame', (t) async {
      _size(t, 390, 844);
      String? seen;
      final router = GoRouter(initialLocation: '/onboarding/documents', routes: [
        GoRoute(path: '/onboarding/documents', builder: (_, _) => const DocumentOnboardingScreen()),
        GoRoute(
          path: '/login',
          builder: (_, s) {
            seen = s.uri.queryParameters['next'];
            return const Scaffold(body: Text('SIGN IN'));
          },
        ),
      ]);
      await t.pumpWidget(ProviderScope(
        overrides: [accountApiProvider.overrideWithValue(DemoAccountApi(DemoBackendState()))],
        child: MaterialApp.router(routerConfig: router, localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate], supportedLocales: const [Locale('en')]),
      ));
      await _settle(t, 6);
      expect(find.text('SIGN IN'), findsOneWidget);
      expect(seen, '/onboarding/documents');
      expect(find.textContaining('Try again'), findsNothing);
    });
  });
}
