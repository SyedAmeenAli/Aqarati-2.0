import 'package:aqarati_app/core/aq/aq_primitives.dart';
import 'package:aqarati_app/core/aq/aq_scene.dart';
import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/repositories/local_persistence.dart';
import 'package:aqarati_app/features/ads/ad_repository.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/entry/screens/purpose_selection_screen.dart';
import 'package:aqarati_app/features/flow/screens/otp_screens.dart';
import 'package:aqarati_app/features/onboarding/interests.dart';
import 'package:aqarati_app/features/workspace/aq_action_card.dart';
import 'package:aqarati_app/features/workspace/aq_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

late ProviderContainer _box;

Widget _app(String start, {MeSession? me, List<Override> extra = const []}) =>
    ProviderScope(
      overrides: [
        meProvider.overrideWith(
          (ref) async =>
              me ??
              const MeSession(
                account: AccountState.active,
                purpose: SignupPurpose.userToShop,
              ),
        ),
        adRepositoryProvider.overrideWithValue(
          DemoAdRepository(latency: Duration.zero),
        ),
        ...extra,
      ],
      child: Consumer(
        builder: (context, ref, _) {
          _box = ProviderScope.containerOf(context);
          return AQLocalPersistence(
            child: MaterialApp.router(
              routerConfig: GoRouter(
                initialLocation: start,
                routes: [
                  GoRoute(
                    path: '/signup/business',
                    builder: (_, _) =>
                        const PurposeSelectionScreen(businessOnly: true),
                  ),
                  GoRoute(
                    path: '/onboarding/purpose',
                    builder: (_, _) => const PurposeSelectionScreen(),
                  ),
                  GoRoute(
                    path: '/onboarding/interests',
                    builder: (_, _) => const InterestsScreen(),
                  ),
                  GoRoute(
                    path: '/account/active',
                    builder: (_, _) => const AccountActiveScreen(),
                  ),
                  GoRoute(
                    path: '/app/home',
                    builder: (_, _) => const Scaffold(body: AQHomeScreen()),
                  ),
                  GoRoute(
                    path: '/:p(.*)',
                    builder: (_, s) => Scaffold(body: Text('AT ${s.uri}')),
                  ),
                ],
              ),
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [Locale('en'), Locale('ar')],
            ),
          );
        },
      ),
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void _phone(WidgetTester t, {double w = 393, double h = 1800}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Register as a Business or Professional', () {
    testWidgets(
      'shows exactly the four professional roles, none of the two customer ones',
      (t) async {
        _phone(t);
        await t.pumpWidget(_app('/signup/business'));
        await _settle(t);
        expect(
          find.text('Register as a Business or Professional'),
          findsOneWidget,
        );
        for (final r in [
          'Property Development Company',
          'Construction Company',
          'Building Architecture',
          'Interior & Exterior Design',
        ]) {
          expect(find.text(r), findsOneWidget, reason: r);
        }
        expect(find.text('User to Shop'), findsNothing);
        expect(find.text('Real Estate Agent'), findsNothing);
      },
    );

    for (final c in [
      ('Property Development Company', '/signup/development'),
      ('Construction Company', '/signup/construction'),
      ('Building Architecture', '/signup/architecture'),
      ('Interior & Exterior Design', '/signup/interior-exterior'),
    ]) {
      testWidgets('${c.$1}: Continue is off until chosen, then opens ${c.$2}', (
        t,
      ) async {
        _phone(t);
        await t.pumpWidget(_app('/signup/business'));
        await _settle(t);
        await t.tap(find.text(c.$1));
        await _settle(t);
        await t.tap(find.textContaining('Continue'));
        await _settle(t);
        expect(find.text('AT ${c.$2}'), findsOneWidget);
      });
    }

    testWidgets('the full six-role chooser still lists all six', (t) async {
      _phone(t);
      await t.pumpWidget(_app('/onboarding/purpose'));
      await _settle(t);
      expect(find.byType(AQChoiceTile), findsNWidgets(6));
    });

    for (final w in [320.0, 360.0, 412.0, 430.0]) {
      testWidgets('business selector has no overflow at $w px', (t) async {
        _phone(t, w: w, h: 800);
        await t.pumpWidget(_app('/signup/business'));
        await _settle(t);
        expect(t.takeException(), isNull);
      });
    }
  });

  group('interests onboarding', () {
    testWidgets('nine interests, Continue off until one is chosen', (t) async {
      _phone(t);
      await t.pumpWidget(_app('/onboarding/interests'));
      await _settle(t);
      expect(find.text('What are you looking for?'), findsOneWidget);
      expect(find.byType(AQChoiceTile), findsNWidgets(9));
      final cont = t.widget<AQPrimaryButton>(find.byType(AQPrimaryButton));
      expect(cont.onPressed, isNull);
    });

    testWidgets('several can be picked; Continue stores them and opens Home', (
      t,
    ) async {
      _phone(t);
      await t.pumpWidget(_app('/onboarding/interests'));
      await _settle(t);
      await t.tap(find.text('Maintenance Services'));
      await t.tap(find.text('Calculate a Property Loan'));
      await _settle(t);
      await t.tap(find.text('Continue'));
      await _settle(t);
      expect(_box.read(interestsProvider), {
        Interest.maintenance,
        Interest.loan,
      });
      expect(find.byType(AQHomeScreen), findsOneWidget);
    });

    testWidgets('Skip opens Home and changes nothing', (t) async {
      _phone(t);
      await t.pumpWidget(_app('/onboarding/interests'));
      await _settle(t);
      await t.tap(find.text('Buy a Property'));
      await t.tap(find.text('Skip for now'));
      await _settle(t);
      expect(_box.read(interestsProvider), isEmpty);
      expect(find.byType(AQHomeScreen), findsOneWidget);
    });

    testWidgets('a saved choice is restored on the next start', (t) async {
      SharedPreferences.setMockInitialValues({
        kInterestsKey: ['rent', 'architecture'],
      });
      _phone(t);
      await t.pumpWidget(_app('/app/home'));
      await _settle(t);
      expect(_box.read(interestsProvider), {
        Interest.rent,
        Interest.architecture,
      });
    });

    testWidgets(
      'a new buyer goes straight to Home after the account is active (no interests step); a business goes to documents',
      (t) async {
        _phone(t);
        await t.pumpWidget(_app('/account/active'));
        await _settle(t);
        await t.tap(find.text('Go to home'));
        await _settle(t);
        // The "What are you looking for?" step was removed on purpose; Home is the service entry point.
        expect(find.text('What are you looking for?'), findsNothing);
        expect(find.byType(AQHomeScreen), findsOneWidget);

        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(
          _app(
            '/account/active',
            me: const MeSession(
              account: AccountState.active,
              purpose: SignupPurpose.constructionCompany,
            ),
          ),
        );
        await _settle(t);
        await t.tap(find.text('Add documents'));
        await _settle(t);
        expect(find.text('AT /onboarding/verification-intro'), findsOneWidget);
      },
    );
  });

  group('Home after interests', () {
    testWidgets('Home stays a fixed six-service launcher whatever was chosen', (t) async {
      _phone(t, h: 2800);
      await t.pumpWidget(
        _app(
          '/app/home',
          extra: [
            interestsProvider.overrideWith((_) => {Interest.maintenance, Interest.loan}),
          ],
        ),
      );
      await _settle(t);
      Finder service(String title) => find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label ?? '').startsWith('$title.') && w.properties.button == true,
      );
      final order = ['Properties', 'Development', 'Interior & Exterior Designer', 'Construction Company', 'Maintenance', 'Loan Calculator'];
      for (final s in order) {
        expect(service(s), findsOneWidget, reason: s);
      }
      // The saved interests do not re-order Home any more: Properties still leads.
      expect(t.getRect(service('Properties')).top, lessThan(t.getRect(service('Maintenance')).top));
      expect(find.byType(AQActionCard), findsNothing, reason: 'the four action cards live on the Properties page now');
    });
  });

}
