import 'dart:typed_data';

import 'package:aqarati_app/admin/admin_app.dart';
import 'package:aqarati_app/admin/admin_repository.dart';
import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/repositories/local_persistence.dart';
import 'package:aqarati_app/features/account/profile_photo.dart';
import 'package:aqarati_app/features/ads/ad_repository.dart';
import 'package:aqarati_app/features/analytics/analytics_charts.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart';
import 'package:aqarati_app/features/devbuild/db_review_widgets.dart';
import 'package:aqarati_app/features/devbuild/db_service_toggles.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/flow/state/document_state.dart';
import 'package:aqarati_app/features/listings/agent_guard.dart';
import 'package:aqarati_app/features/role_home/mode_switch.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The UX refinement: Shop / Work routing with no dead ends, two independent services, the profile photo,
/// review summary and visibility, honest charts, and the phone Admin navigation.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

const _loc = [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate];

MeSession _me(SignupPurpose p, GrantState? g) => MeSession(account: AccountState.active, purpose: p, grant: g);

late ProviderContainer _box;
final _visited = <String>[];

Finder get _memImage => find.byWidgetPredicate((w) => w is Image && w.image is MemoryImage);

/// A tiny router that records where the gates send people. `/` is the page under test.
Widget _app(Widget home, {MeSession? me, List<Override> extra = const [], bool rtl = false}) => ProviderScope(
  overrides: [
    meProvider.overrideWith((ref) async => me ?? (throw Exception('guest'))),
    ...extra,
  ],
  child: Consumer(
    builder: (context, ref, _) {
      _box = ProviderScope.containerOf(context);
      return AQLocalPersistence(
        child: MaterialApp.router(
          locale: Locale(rtl ? 'ar' : 'en'),
          localizationsDelegates: _loc,
          supportedLocales: const [Locale('en'), Locale('ar')],
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => Scaffold(body: home)),
            GoRoute(path: '/:p(.*)', builder: (_, s) {
              _visited.add(s.uri.toString());
              return Scaffold(body: Text('AT ${s.uri}'));
            }),
          ]),
        ),
      );
    },
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void _size(WidgetTester t, double w, [double h = 1600]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

class _FakePicker implements DocumentPicker {
  final Uint8List? bytes;
  _FakePicker(this.bytes);
  @override
  Future<PickedDocument?> pick() async => bytes == null ? null : PickedDocument(name: 'me.png', sizeBytes: bytes!.length, bytes: bytes!);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    _visited.clear();
  });

  group('Shop and Work routing: no dead ends, no welcome screen', () {
    testWidgets('a signed-out person opening Shop is sent to sign in, with the destination remembered', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const ShopGate()));
      await _settle(t);
      expect(_visited.last, startsWith('/login?as=user&next='));
      expect(Uri.parse(_visited.last).queryParameters['next'], '/app/home');
    });

    testWidgets('a signed-out person opening Work is sent to sign in as an agent, returning to Work', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const WorkGate()));
      await _settle(t);
      expect(Uri.parse(_visited.last).path, '/login');
      expect(Uri.parse(_visited.last).queryParameters, {'as': 'agent', 'next': '/work'});
    });

    testWidgets('a signed-in customer opening Shop goes straight to the customer home', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const ShopGate(), me: _me(SignupPurpose.userToShop, null)));
      await _settle(t);
      expect(_visited.last, '/app/home');
    });

    testWidgets('an approved agent opening Work enters the agent workspace and the choice is kept', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const WorkGate(), me: _me(SignupPurpose.realEstateAgent, GrantState.approved)));
      await _settle(t);
      expect(_visited.last, '/agent');
      expect(_box.read(homeWorkspaceProvider), HomeWorkspace.agent);
    });

    testWidgets('an approved business opening Work enters its workspace', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const WorkGate(), me: _me(SignupPurpose.constructionCompany, GrantState.approved)));
      await _settle(t);
      expect(_visited.last, '/pro');
    });

    testWidgets('a customer with no professional account sees why, and a real next step, not a dead end', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const WorkGate(), me: _me(SignupPurpose.userToShop, null)));
      await _settle(t);
      expect(find.text('Business workspace only'), findsWidgets);
      expect(find.text('Register as a Business or Professional'), findsOneWidget);
      expect(find.text('Continue shopping'), findsOneWidget);
      await t.tap(find.text('Register as a Business or Professional'));
      await _settle(t);
      expect(_visited.last, '/signup/business');
    });

    testWidgets('an application still in review shows its status link instead', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const WorkGate(), me: _me(SignupPurpose.realEstateAgent, GrantState.pendingVerification)));
      await _settle(t);
      expect(find.text('View application status'), findsOneWidget);
      await t.tap(find.text('View application status'));
      await _settle(t);
      expect(_visited.last, '/verification');
    });

    testWidgets('the agent guard offers Sign in to a guest and never sends them back to the welcome screen', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(AgentGuard(title: 'Dashboard', backFallback: '/entry', builder: (_) => const Text('INSIDE'))));
      await _settle(t);
      expect(find.text('INSIDE'), findsNothing);
      expect(find.text('Sign in'), findsOneWidget);
      await t.tap(find.text('Sign in'));
      await _settle(t);
      expect(Uri.parse(_visited.last).path, '/login');
      expect(_visited.where((v) => v.startsWith('/entry')), isEmpty);
    });

    testWidgets('Shop and Work switching keeps the same account (the provider only changes the workspace)', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(Consumer(builder: (c, ref, _) => Column(children: [
        TextButton(onPressed: () => switchToShop(c, ref), child: const Text('SHOP')),
        TextButton(onPressed: () => switchToWork(c, ref), child: const Text('WORK')),
      ])), me: _me(SignupPurpose.realEstateAgent, GrantState.approved)));
      await _settle(t);
      await t.tap(find.text('SHOP'));
      await _settle(t);
      expect(_visited.last, '/app/home');
      expect(_box.read(homeWorkspaceProvider), HomeWorkspace.buyer);
      expect((await _box.read(meProvider.future)).purpose, SignupPurpose.realEstateAgent, reason: 'the account is unchanged');
    });
  });

  group('two independent services', () {
    test('the combined value is derived, never a third option', () {
      expect(serviceFromFlags(true, false), InteriorExteriorServiceType.interior);
      expect(serviceFromFlags(false, true), InteriorExteriorServiceType.exterior);
      expect(serviceFromFlags(true, true), InteriorExteriorServiceType.both);
      expect(serviceFromFlags(false, false), isNull);
      expect(serviceFlags(InteriorExteriorServiceType.both), (interior: true, exterior: true));
      expect(serviceFlags(null), (interior: false, exterior: false));
    });

    testWidgets('each switch changes only its own service, and both off means none', (t) async {
      _size(t, 390);
      var v = InteriorExteriorServiceType.interior as InteriorExteriorServiceType?;
      await t.pumpWidget(_app(StatefulBuilder(builder: (c, set) => DbServiceToggles(value: v, onChanged: (x) => set(() => v = x))), me: _me(SignupPurpose.interiorExteriorDesign, GrantState.approved)));
      await _settle(t);
      expect(find.text('Offered: Interior Design'), findsOneWidget);
      await t.tap(find.text('Exterior Design'));
      await _settle(t);
      expect(v, InteriorExteriorServiceType.both);
      expect(find.text('Offered: Interior + Exterior'), findsOneWidget);
      await t.tap(find.text('Interior Design'));
      await _settle(t);
      expect(v, InteriorExteriorServiceType.exterior);
      await t.tap(find.text('Exterior Design'));
      await _settle(t);
      expect(v, isNull);
      expect(find.text('Choose at least one service.'), findsOneWidget);
      expect(find.text('Both'), findsNothing, reason: '"Both" is never offered as a choice');
    });

    testWidgets('a sign-up needs one service: the last switch cannot be turned off', (t) async {
      _size(t, 320);
      var v = InteriorExteriorServiceType.exterior as InteriorExteriorServiceType?;
      await t.pumpWidget(_app(StatefulBuilder(builder: (c, set) => DbServiceToggles(allowNone: false, value: v, onChanged: (x) => set(() => v = x)))));
      await _settle(t);
      await t.tap(find.text('Exterior Design'));
      await _settle(t);
      expect(v, InteriorExteriorServiceType.exterior);
      expect(t.takeException(), isNull);
    });

    testWidgets('no overflow at 200% text, in Arabic', (t) async {
      _size(t, 320);
      await t.pumpWidget(_app(MediaQuery(data: const MediaQueryData(size: Size(320, 1600), textScaler: TextScaler.linear(2)), child: DbServiceToggles(value: InteriorExteriorServiceType.both, onChanged: (_) {})), rtl: true));
      await _settle(t);
      expect(t.takeException(), isNull);
    });
  });

  group('profile photo', () {
    testWidgets('no photo shows the person icon; a chosen photo is shown everywhere AQAvatar is used', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const AQAvatar(size: 56)));
      await _settle(t);
      expect(find.byType(Image), findsNothing);
      _box.read(profilePhotoProvider.notifier).state = ProfilePhoto(Uint8List.fromList(_png));
      await _settle(t);
      expect(find.byType(Image), findsOneWidget);
      _box.read(profilePhotoProvider.notifier).state = null;
      await _settle(t);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('add, preview, save, change and remove', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const ProfilePhotoScreen(), extra: [documentPickerProvider.overrideWithValue(_FakePicker(Uint8List.fromList(_png)))]));
      await _settle(t);
      expect(find.text('Add photo'), findsOneWidget);
      await t.tap(find.text('Add photo'));
      await _settle(t);
      // One shared editor: preview, frame, then confirm.
      expect(find.text('Use this picture'), findsOneWidget);
      await t.tap(find.text('Use this picture'));
      await _settle(t);
      expect(_memImage, findsOneWidget, reason: 'the chosen picture is previewed');
      expect(_box.read(profilePhotoProvider), isNull, reason: 'nothing is applied before Save');
      expect(find.text('Change photo'), findsOneWidget);
      await t.tap(find.text('Save photo'));
      await _settle(t);
      expect(_box.read(profilePhotoProvider), isNotNull);
      expect(_visited.last, '/app/account');
    });

    testWidgets('a PDF or a non-picture is refused with a clear message', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const ProfilePhotoScreen(), extra: [documentPickerProvider.overrideWithValue(_FakePicker(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3])))]));
      await _settle(t);
      await t.tap(find.text('Add photo'));
      await _settle(t);
      expect(find.text('Choose a JPG or PNG picture.'), findsOneWidget);
      expect(_memImage, findsNothing);
    });

    testWidgets('Remove clears the draft and saving removes the photo everywhere', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(const ProfilePhotoScreen(), extra: [profilePhotoProvider.overrideWith((ref) => ProfilePhoto(Uint8List.fromList(_png)))]));
      await _settle(t);
      expect(find.text('Change photo'), findsOneWidget);
      await t.tap(find.text('Change photo'));
      await _settle(t);
      await t.tap(find.text('Remove photo'));
      await _settle(t);
      await t.tap(find.text('Save photo'));
      await _settle(t);
      expect(_box.read(profilePhotoProvider), isNull);
    });
  });

  group('reviews', () {
    final list = [
      DbReview(id: '1', rating: 5, body: 'a', author: 'x', at: DateTime(2026)),
      DbReview(id: '2', rating: 5, body: 'b', author: 'x', at: DateTime(2026)),
      DbReview(id: '3', rating: 4, body: 'c', author: 'x', at: DateTime(2026)),
    ];
    testWidgets('the average, the count and the bars are computed from the listed reviews', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(DbRatingSummary(reviews: list)));
      await _settle(t);
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('3 reviews'), findsOneWidget);
      expect(find.text('2'), findsNWidgets(2), reason: 'the 2-star label and the two five-star reviews');
    });

    testWidgets('a visibility switch really changes its state and the label', (t) async {
      _size(t, 390);
      await t.pumpWidget(_app(Consumer(builder: (c, ref, _) => DbSettingToggle(title: 'Show reviews', sub: 'on the profile', value: ref.watch(reviewsPublicProvider), onChanged: (v) => ref.read(reviewsPublicProvider.notifier).state = v))));
      await _settle(t);
      expect(_box.read(reviewsPublicProvider), isTrue);
      await t.tap(find.text('Show reviews'));
      await _settle(t);
      expect(_box.read(reviewsPublicProvider), isFalse);
    });
  });

  group('honest charts', () {
    testWidgets('a column chart reads one week on tap and keeps its reading inside the chart', (t) async {
      _size(t, 320);
      final handle = t.ensureSemantics();
      await t.pumpWidget(_app(const AQColumnChart(values: <double>[3, 5, 4, 9, 6, 8, 7, 12], labels: ['1/9', '2/9', '3/9', '4/9', '5/9', '6/9', '7/9', '8/9'], semanticsLabel: 'Leads')));
      await t.pump(const Duration(seconds: 1));
      final r = t.getRect(find.byType(AQColumnChart));
      await t.tapAt(Offset(r.right - 8, r.center.dy));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(RegExp(r'^Leads\. 8/9: 12$')), findsOneWidget);
      expect(t.takeException(), isNull);
      handle.dispose();
    });
  });

  group('Admin on a phone', () {
    Widget admin() => ProviderScope(
      overrides: adminOverrides(DemoAdminStore(latency: Duration.zero, ads: DemoAdRepository(latency: Duration.zero))),
      child: Consumer(builder: (context, ref, _) {
        _box = ProviderScope.containerOf(context);
        return const AdminApp();
      }),
    );

    Future<void> login(WidgetTester t) async {
      await t.enterText(find.widgetWithText(TextField, 'Email'), 'super@demo.test');
      await t.enterText(find.widgetWithText(TextField, 'Password'), DemoAdminStore.demoPassword);
      await t.tap(find.text('Continue'));
      await _settle(t);
      await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
      await _settle(t);
    }

    for (final w in <double>[320, 390]) {
      testWidgets('at $w px: bottom bar with four destinations, a drawer that fits, a close button, filters that wrap', (t) async {
        _size(t, w, 900);
        await t.pumpWidget(admin());
        await _settle(t);
        await login(t);
        expect(t.takeException(), isNull);
        for (final d in ['Overview', 'Accounts', 'Listings', 'More']) {
          expect(find.text(d), findsWidgets, reason: d);
        }
        // More opens the drawer, which fits the phone and can be closed
        await t.tap(find.text('More').last);
        await _settle(t);
        final drawerW = t.getSize(find.byType(Drawer)).width;
        expect(drawerW, lessThanOrEqualTo(w * 0.86 + 1));
        // The drawer folds destinations into sections; open People to reach Agents and brokers.
        expect(find.text('Agents and brokers'), findsNothing, reason: 'sections start folded unless they hold the current page');
        await t.tap(find.text('People'));
        await t.pumpAndSettle();
        expect(find.text('Agents and brokers'), findsOneWidget);
        await t.tap(find.bySemanticsLabel('Close navigation'));
        await _settle(t);
        expect(find.byType(Drawer), findsNothing);
        // a destination in the drawer closes it and navigates
        GoRouter.of(t.element(find.byType(Scaffold).first)).go('/accounts');
        await _settle(t);
        expect(find.text('Real Estate Agent'), findsWidgets);
        // On a phone the filters are one swipeable line: the first chips are on screen, the rest scroll.
        expect(t.getRect(find.text('All').first).right, lessThanOrEqualTo(w), reason: 'the first filter chip is on screen');
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('a tablet gets a navigation rail, not a bottom bar', (t) async {
      _size(t, 768, 1000);
      await t.pumpWidget(admin());
      await _settle(t);
      await login(t);
      expect(find.text('More'), findsOneWidget);
      expect(t.getTopLeft(find.text('More')).dx, lessThan(100), reason: 'on the leading edge');
      expect(t.takeException(), isNull);
    });
  });
}
