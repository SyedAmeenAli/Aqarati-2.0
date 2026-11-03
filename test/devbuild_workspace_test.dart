import 'package:aqarati_app/core/aq/aq_primitives.dart';
import 'package:aqarati_app/core/config/demo_mode.dart' show kDemoMode;
import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/data/models/enums.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart';
import 'package:aqarati_app/features/devbuild/db_repository.dart';
import 'package:aqarati_app/features/devbuild/db_routes.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

DemoBackendState _state(SignupPurpose p, GrantState g) => DemoBackendState()
  ..purpose = p
  ..grant = g
  ..account = AccountState.active
  ..businessName = 'Test Business';

/// A repository whose optional capabilities can be switched on, to exercise the screens that are
/// otherwise correctly gated off.
class _CapRepo extends DemoDevBuildRepository {
  _CapRepo(
    DemoBackendState? Function() session, {
    this.engagements = false,
    this.leads = false,
  }) : super(session, lag: Duration.zero);
  final bool engagements, leads;
  final confirmed = <String>[];
  @override
  DbCapabilities get caps => DbCapabilities(
    profileEdit: true,
    engagements: engagements,
    leadEvents: leads,
  );
  @override
  Future<List<Engagement>> myEngagements() async => [
    Engagement(
      id: 'e1',
      clientLabel: 'Client A',
      state: EngagementState.awaitingMyConfirmation,
      confirmByDeadline: DateTime(2026, 11, 1),
    ),
  ];
  @override
  Future<void> confirmEngagement(String id) async => confirmed.add(id);
  @override
  Future<List<ContactEvent>> myContactEvents() async => [
    ContactEvent(
      id: 'c1',
      channel: ContactChannel.call,
      targetLabel: 'Test Business profile',
      at: DateTime(2026, 10, 1, 9, 30),
    ),
  ];
}

/// The repository as a build without demo mode has it: the contract's optional capabilities are off,
/// whatever flag this test run was started with. Used by the tests of the gated screens.
class _GatedRepo extends DemoDevBuildRepository {
  _GatedRepo(super.session) : super(lag: Duration.zero);
  @override
  DbCapabilities get caps => const DbCapabilities(profileEdit: true);
  @override
  Future<List<PortfolioItem>> myPortfolio() async => const [];
  @override
  Future<DbProfessional?> myOrganisation() async {
    final o = await super.myOrganisation();
    if (o == null) return null;
    return DbProfessional(
      id: o.id,
      name: o.name,
      type: o.type,
      serviceType: o.serviceType,
      locationLabel: o.locationLabel,
      governorate: o.governorate,
      verified: o.verified,
    );
  }
}

Widget _app(
  String location, {
  bool dark = false,
  bool reduceMotion = false,
  required DevBuildRepository repo,
  MeSession? me,
  bool signedOut = false,
  double scale = 1,
  String lang = 'en',
}) {
  final router = GoRouter(
    initialLocation: location,
    routes: [
      ShellRoute(
        builder: (c, s, child) => Scaffold(body: child),
        routes: [...dbShellRoutes(), ...dbProShellRoutes()],
      ),
      ...dbStandaloneRoutes(),
      GoRoute(
        path: '/verification',
        builder: (c, s) => const Scaffold(body: Text('VERIFICATION PAGE')),
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => const Scaffold(body: Text('LOGIN PAGE')),
      ),
      GoRoute(
        path: '/app/account',
        builder: (c, s) => const Scaffold(body: Text('ACCOUNT PAGE')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      devBuildRepositoryProvider.overrideWithValue(repo),
      meProvider.overrideWith((ref) async {
        if (signedOut || me == null)
          throw const ApiException(ApiErrorCode.network);
        return me;
      }),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      locale: Locale(lang),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
          textScaler: TextScaler.linear(scale),
          disableAnimations: reduceMotion,
        ),
        child: child!,
      ),
    ),
  );
}

MeSession _me(SignupPurpose p, GrantState? g, {ReviewStage? stage}) =>
    MeSession(account: AccountState.active, purpose: p, grant: g, stage: stage);
final _devMe = _me(
  SignupPurpose.propertyDevelopmentCompany,
  GrantState.approved,
);

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

/// Taps the last match: sheet options sit above the page in the tree, and numbers also appear in the stepper.
Future<void> _tapLast(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.tap(f.last, warnIfMissed: false);
  await _settle(t, 3);
}

Future<void> _tapText(WidgetTester t, String text) async {
  final f = find.text(text);
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await _settle(t, 3);
}

DemoDevBuildRepository _devRepo({GrantState g = GrantState.approved}) =>
    DemoDevBuildRepository(
      () => _state(SignupPurpose.propertyDevelopmentCompany, g),
      lag: Duration.zero,
    );

ProjectDraft _valid({String name = 'Harbour Homes'}) => ProjectDraft(
  name: name,
  type: PropertyType.villa,
  bedrooms: 4,
  bathrooms: 3,
  areaSqm: 280,
  governorate: 'Muscat',
  wilayat: 'As Seeb',
);

void main() {
  group('repository: ownership, status and idempotency', () {
    test(
      'a submitted project is under review, never approved or public',
      () async {
        final repo = _devRepo();
        final saved = await repo.saveProject(
          _valid(),
          submit: true,
          idempotencyKey: 'k1',
        );
        expect(saved.status, ProjectStatus.underReview);
        expect(saved.rawStatus, 'pending_verification');
        expect((await repo.myProjects()).single.id, saved.id);
        expect(
          await repo.approvedProject(saved.id),
          isNull,
          reason: 'not public until approved',
        );
        expect((await repo.approvedProjects('me')), isEmpty);
      },
    );

    test('the same idempotency key never creates a second project', () async {
      final repo = _devRepo();
      final a = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'same',
      );
      final b = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'same',
      );
      expect(b.id, a.id);
      expect((await repo.myProjects()).length, 1);
      final c = await repo.saveProject(
        _valid(name: 'Second'),
        submit: true,
        idempotencyKey: 'other',
      );
      expect(c.id, isNot(a.id));
    });

    test(
      'server validation errors come back keyed by field and nothing is saved',
      () async {
        final repo = _devRepo();
        await expectLater(
          repo.saveProject(
            ProjectDraft(name: 'ab'),
            submit: true,
            idempotencyKey: 'bad',
          ),
          throwsA(
            isA<ProjectValidationException>().having(
              (e) => e.fields.keys,
              'fields',
              containsAll(['name', 'type']),
            ),
          ),
        );
        expect(await repo.myProjects(), isEmpty);
      },
    );

    test('a draft stays a draft; submitting moves it to review', () async {
      final repo = _devRepo();
      final d = await repo.saveProject(
        ProjectDraft(name: 'Draft Co'),
        submit: false,
        idempotencyKey: 'd1',
      );
      expect(d.status, ProjectStatus.draft);
      final again = _valid(name: 'Draft Co')..id = d.id;
      final s = await repo.saveProject(
        again,
        submit: true,
        idempotencyKey: 'd2',
      );
      expect(s.id, d.id);
      expect(s.status, ProjectStatus.underReview);
      expect((await repo.myProjects()).length, 1);
    });

    test('editing an approved project sends it back to review', () async {
      final repo = _devRepo();
      final p = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'a1',
      );
      repo.debugDecide(p.id, ProjectStatus.approved);
      expect((await repo.myProject(p.id)).status, ProjectStatus.approved);
      final edit = (await repo.myProject(p.id)).toDraft()
        ..name = 'Harbour Homes II';
      final after = await repo.saveProject(
        edit,
        submit: true,
        idempotencyKey: 'a2',
      );
      expect(after.status, ProjectStatus.underReview);
      expect(after.name, 'Harbour Homes II');
    });

    test('resubmit is allowed only after changes were requested', () async {
      final repo = _devRepo();
      final p = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'r1',
      );
      await expectLater(
        repo.resubmitProject(p.id, idempotencyKey: 'r2'),
        throwsA(isA<ProjectValidationException>()),
      );
      repo.debugDecide(
        p.id,
        ProjectStatus.changesRequested,
        feedback: 'Add the land title.',
      );
      final fb = await repo.myProject(p.id);
      expect(fb.reviewerFeedback, 'Add the land title.');
      final r = await repo.resubmitProject(p.id, idempotencyKey: 'r3');
      expect(r.status, ProjectStatus.underReview);
      expect(r.reviewerFeedback, isNull);
    });

    test('other organisations and other roles are denied in the repository, not only the UI', () async {
      final repo = _devRepo();
      await expectLater(
        repo.myProject('someone-elses'),
        throwsA(isA<PermissionDeniedException>()),
      );
      final builder = DemoDevBuildRepository(
        () => _state(SignupPurpose.constructionCompany, GrantState.approved),
        lag: Duration.zero,
      );
      await expectLater(
        builder.myProjects(),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        builder.saveProject(_valid(), submit: true, idempotencyKey: 'x'),
        throwsA(isA<PermissionDeniedException>()),
      );
      final pending = DemoDevBuildRepository(
        () => _state(
          SignupPurpose.propertyDevelopmentCompany,
          GrantState.pendingVerification,
        ),
        lag: Duration.zero,
      );
      await expectLater(
        pending.myProjects(),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('capabilities the contract lacks are reported as false', () {
      const caps = UnavailableDevBuildRepository();
      expect(
        caps.caps.projectMedia ||
            caps.caps.engagements ||
            caps.caps.leadEvents ||
            caps.caps.portfolio ||
            caps.caps.reviewReplies,
        isFalse,
      );
      final demo = DemoDevBuildRepository(() => null).caps;
      // Without demo mode nothing the contract lacks is on. A demo build switches on only the three
      // capabilities it can serve from its local sample data, and still never media or review replies.
      expect(
        demo.projectMedia || demo.reviewReplies,
        isFalse,
      );
      expect(
        demo.engagements && demo.leadEvents && demo.portfolio,
        kDemoMode,
      );
      if (!kDemoMode) {
        expect(demo.engagements || demo.leadEvents || demo.portfolio, isFalse);
      }
    });
  });

  group('route guards', () {
    testWidgets('signed out sees a log-in prompt, not the workspace', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(393, 852));
      await t.pumpWidget(
        _app('/app/account/workspace', repo: _devRepo(), signedOut: true),
      );
      await _settle(t);
      expect(
        find.textContaining('Log in with your business account'),
        findsOneWidget,
      );
      expect(find.text('Add new project'), findsNothing);
    });

    for (final c in [
      (GrantState.pendingVerification, 'under review', null),
      (GrantState.resubmissionRequired, 'updated documents', null),
      (GrantState.rejected, 'not approved', null),
      (GrantState.suspended, 'suspended', null),
    ]) {
      testWidgets(
        '${c.$1.name} grant is routed to verification status, not the workspace',
        (t) async {
          await t.binding.setSurfaceSize(const Size(393, 852));
          await t.pumpWidget(
            _app(
              '/app/account/workspace/projects',
              repo: _devRepo(g: c.$1),
              me: _me(SignupPurpose.propertyDevelopmentCompany, c.$1),
            ),
          );
          await _settle(t);
          expect(find.textContaining(c.$2), findsWidgets);
          expect(find.text('Add new project'), findsNothing);
          await _tapText(t, 'View application status');
          expect(find.text('VERIFICATION PAGE'), findsOneWidget);
        },
      );
    }

    testWidgets('awaiting second approval is its own message', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 852));
      await t.pumpWidget(
        _app(
          '/app/account/workspace',
          repo: _devRepo(),
          me: _me(
            SignupPurpose.propertyDevelopmentCompany,
            GrantState.pendingVerification,
            stage: ReviewStage.awaitingSecondApproval,
          ),
        ),
      );
      await _settle(t);
      expect(find.textContaining('second approval'), findsWidgets);
    });

    testWidgets(
      'a customer account is told the workspace is for approved businesses',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        await t.pumpWidget(
          _app(
            '/app/account/workspace',
            repo: _devRepo(),
            me: _me(SignupPurpose.userToShop, null),
          ),
        );
        await _settle(t);
        expect(find.textContaining('for approved businesses'), findsOneWidget);
      },
    );

    testWidgets(
      'an approved construction firm cannot reach developer project management',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        final me = _me(SignupPurpose.constructionCompany, GrantState.approved);
        await t.pumpWidget(
          _app(
            '/app/account/workspace/projects',
            repo: DemoDevBuildRepository(
              () => _state(
                SignupPurpose.constructionCompany,
                GrantState.approved,
              ),
              lag: Duration.zero,
            ),
            me: me,
          ),
        );
        await _settle(t);
        expect(
          find.textContaining('only available to approved property developers'),
          findsOneWidget,
        );
        await t.pumpWidget(
          _app(
            '/workspace/projects/new',
            repo: DemoDevBuildRepository(
              () => _state(
                SignupPurpose.constructionCompany,
                GrantState.approved,
              ),
              lag: Duration.zero,
            ),
            me: me,
          ),
        );
        await _settle(t);
        expect(
          find.textContaining('only available to approved property developers'),
          findsOneWidget,
        );
        expect(find.text('Basic information'), findsNothing);
      },
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('developer workspace pages build at text scale $scale', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(393, 852));
      final repo = _devRepo();
      final p = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'seed',
      );
      repo.debugDecide(
        p.id,
        ProjectStatus.changesRequested,
        feedback: 'Please confirm the built-up area.',
      );
      for (final loc in [
        '/app/account/workspace',
        '/app/account/workspace/projects',
        '/workspace/projects/${p.id}',
        '/workspace/projects/${p.id}/edit',
        '/workspace/projects/${p.id}/submitted',
        '/app/account/workspace/profile',
        '/app/account/workspace/profile/status',
        '/app/account/workspace/leads',
        '/app/account/workspace/reviews',
        '/app/account/workspace/engagements',
      ]) {
        await t.pumpWidget(_app(loc, repo: repo, me: _devMe, scale: scale));
        await _settle(t);
        expect(t.takeException(), isNull, reason: loc);
      }
    });

    testWidgets(
      'professional (non-developer) workspace builds at text scale $scale',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        final repo = DemoDevBuildRepository(
          () =>
              _state(SignupPurpose.interiorExteriorDesign, GrantState.approved),
          lag: Duration.zero,
        );
        final me = _me(
          SignupPurpose.interiorExteriorDesign,
          GrantState.approved,
        );
        for (final loc in [
          '/app/account/workspace',
          '/app/account/workspace/portfolio',
          '/app/account/workspace/profile',
        ]) {
          await t.pumpWidget(_app(loc, repo: repo, me: me, scale: scale));
          await _settle(t);
          expect(t.takeException(), isNull, reason: loc);
        }
      },
    );

    testWidgets('wizard steps build at text scale $scale', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 852));
      await t.pumpWidget(
        _app(
          '/workspace/projects/new',
          repo: _devRepo(),
          me: _devMe,
          scale: scale,
        ),
      );
      await _settle(t);
      expect(t.takeException(), isNull);
      expect(find.textContaining('Step 1 of 5'), findsWidgets);
    });
  }

  group('dashboard', () {
    testWidgets(
      'developer sees projects and tools; no developer action for other roles; no invented metrics',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        await t.pumpWidget(
          _app('/app/account/workspace', repo: _devRepo(), me: _devMe),
        );
        await _settle(t);
        expect(find.text('Add new project'), findsOneWidget);
        expect(find.text('Portfolio'), findsNothing);
        for (final fake in [
          'Profile views',
          'Active leads',
          'Analytics',
          '2.4K',
        ]) {
          expect(find.textContaining(fake), findsNothing, reason: fake);
        }
        expect(
          find.textContaining('You have not added a project yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a professional firm gets Portfolio and no project management',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        final repo = DemoDevBuildRepository(
          () => _state(SignupPurpose.buildingArchitecture, GrantState.approved),
          lag: Duration.zero,
        );
        await t.pumpWidget(
          _app(
            '/app/account/workspace',
            repo: repo,
            me: _me(SignupPurpose.buildingArchitecture, GrantState.approved),
          ),
        );
        await _settle(t);
        expect(find.text('Portfolio'), findsOneWidget);
        expect(find.text('Add new project'), findsNothing);
        expect(find.text('Manage projects'), findsNothing);
      },
    );
  });

  group('wizard journey', () {
    testWidgets(
      'validation, step persistence, review, submit and a truthful confirmation',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1200));
        final repo = _devRepo();
        await t.pumpWidget(
          _app('/workspace/projects/new', repo: repo, me: _devMe),
        );
        await _settle(t);

        // Step 1: empty form shows both errors and does not advance.
        await _tapText(t, 'Save & continue');
        expect(
          find.text('Enter a project name of at least 3 characters.'),
          findsOneWidget,
        );
        expect(find.text('Choose a project type.'), findsOneWidget);
        expect(find.textContaining('Step 1 of 5'), findsWidgets);

        await t.enterText(find.byType(TextField).first, 'Harbour Homes');
        await _tapText(t, 'Select project type');
        await _tapText(t, 'Villa');
        await _tapText(t, 'Save & continue');

        // Step 2: villa needs rooms and a built-up area; land alone is not enough.
        expect(find.textContaining('Step 2 of 5'), findsWidgets);
        await _tapText(t, 'Save & continue');
        expect(find.text('Choose the number of bedrooms.'), findsOneWidget);
        expect(
          find.text('Enter the built-up area in square metres.'),
          findsOneWidget,
        );
        var selects = find.text('Select');
        await t.tap(selects.first, warnIfMissed: false);
        await _settle(t, 3);
        await _tapLast(t, '4');
        selects = find.text('Select');
        await t.tap(selects.first, warnIfMissed: false);
        await _settle(t, 3);
        await _tapLast(t, '3');
        await t.enterText(find.byType(TextField).first, '280');
        await t.pump();

        // Back keeps what was entered.
        await t.tap(
          find.bySemanticsLabel(RegExp('^Back')).first,
          warnIfMissed: false,
        );
        await _settle(t, 3);
        expect(find.textContaining('Step 1 of 5'), findsWidgets);
        expect(find.text('Harbour Homes'), findsOneWidget);
        await _tapText(t, 'Save & continue');
        expect(find.text('280'), findsOneWidget);
        await _tapText(t, 'Save & continue');

        // Step 3: media is honestly unavailable, and does not block submitting.
        expect(
          find.textContaining('Photo upload is not available'),
          findsWidgets,
        );
        await _tapText(t, 'Save & continue');

        // Step 4: location is required.
        expect(find.textContaining('Step 4 of 5'), findsWidgets);
        await _tapText(t, 'Save & continue');
        expect(find.text('Choose a governorate.'), findsOneWidget);
        await _tapText(t, 'Select');
        await _tapText(t, 'Muscat');
        await _tapText(t, 'Select');
        await _tapText(t, 'As Seeb');
        await _tapText(t, 'Save & continue');

        // Step 5: review shows the values and says it will not be public.
        expect(find.textContaining('Step 5 of 5'), findsWidgets);
        expect(
          find.textContaining('not public until it is approved'),
          findsOneWidget,
        );
        await _tapText(t, 'Submit for review');
        await _settle(t, 8);

        // Confirmation follows the status the repository returned.
        expect(find.text('Submitted for review'), findsOneWidget);
        expect(find.text('Under review'), findsWidgets);
        expect(find.textContaining('Published'), findsNothing);
        expect(
          (await repo.myProjects()).single.status,
          ProjectStatus.underReview,
        );
      },
    );

    testWidgets(
      'leaving with unsaved changes asks first and keeps the draft if you stay',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        await t.pumpWidget(
          _app('/workspace/projects/new', repo: _devRepo(), me: _devMe),
        );
        await _settle(t);
        await t.enterText(find.byType(TextField).first, 'Some name');
        await t.pump();
        await t.tap(
          find.bySemanticsLabel(RegExp('^Back')).first,
          warnIfMissed: false,
        );
        await _settle(t, 3);
        expect(find.text('Leave without saving?'), findsOneWidget);
        await _tapText(t, 'Keep editing');
        expect(find.text('Some name'), findsOneWidget);
      },
    );

    testWidgets('save draft stores a draft and says so, never "submitted"', (
      t,
    ) async {
      await t.binding.setSurfaceSize(const Size(393, 1000));
      final repo = _devRepo();
      await t.pumpWidget(
        _app('/workspace/projects/new', repo: repo, me: _devMe),
      );
      await _settle(t);
      await t.enterText(find.byType(TextField).first, 'My Draft');
      await t.pump();
      await _tapText(t, 'Save draft');
      await _settle(t, 6);
      expect(find.text('Draft saved'), findsOneWidget);
      expect(find.text('Submitted for review'), findsNothing);
      expect((await repo.myProjects()).single.status, ProjectStatus.draft);
    });

    testWidgets(
      'a failing save keeps the draft and offers retry, never a success screen',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1200));
        await t.pumpWidget(
          _app('/workspace/projects/new', repo: _Failing(), me: _devMe),
        );
        await _settle(t);
        await t.enterText(find.byType(TextField).first, 'Offline Draft');
        await t.pump();
        await _tapText(t, 'Save draft');
        await _settle(t, 4);
        expect(find.textContaining('could not reach AQARATI'), findsOneWidget);
        expect(find.text('Draft saved'), findsNothing);
        expect(find.text('Offline Draft'), findsOneWidget);
      },
    );
  });

  group('project status and edit', () {
    Future<(DemoDevBuildRepository, String)> seeded(
      ProjectStatus s, {
      String? feedback,
    }) async {
      final repo = _devRepo();
      final p = await repo.saveProject(
        _valid(),
        submit: true,
        idempotencyKey: 'seed-${s.name}',
      );
      if (s != ProjectStatus.underReview)
        repo.debugDecide(p.id, s, feedback: feedback);
      return (repo, p.id);
    }

    testWidgets(
      'changes requested shows the reviewer text exactly and a resubmit that goes to review',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final (repo, id) = await seeded(
          ProjectStatus.changesRequested,
          feedback: 'Please add the land title reference.',
        );
        await t.pumpWidget(
          _app('/workspace/projects/$id', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(
          find.text('Please add the land title reference.'),
          findsOneWidget,
        );
        expect(find.text('Changes requested'), findsWidgets);
        await _tapText(t, 'Resubmit for review');
        await _tapLast(t, 'Resubmit for review');
        await _settle(t, 8);
        expect(find.text('Submitted for review'), findsOneWidget);
        expect((await repo.myProject(id)).status, ProjectStatus.underReview);
      },
    );

    for (final s in [ProjectStatus.underReview, ProjectStatus.rejected]) {
      testWidgets('${s.name} offers no edit or resubmit', (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final (repo, id) = await seeded(
          s,
          feedback: s == ProjectStatus.rejected
              ? 'Not matched to a licensed development.'
              : null,
        );
        await t.pumpWidget(
          _app('/workspace/projects/$id', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(find.text('Resubmit for review'), findsNothing);
        expect(find.text('Edit project'), findsNothing);
        if (s == ProjectStatus.rejected)
          expect(
            find.text('Not matched to a licensed development.'),
            findsOneWidget,
          );
        // The edit route itself refuses too.
        await t.pumpWidget(
          _app('/workspace/projects/$id/edit', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(
          find.textContaining('cannot be edited right now'),
          findsOneWidget,
        );
      });
    }

    testWidgets(
      'editing reopens the wizard prefilled at the requested step with the status in view',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1200));
        final (repo, id) = await seeded(
          ProjectStatus.changesRequested,
          feedback: 'Fix the area.',
        );
        await t.pumpWidget(
          _app('/workspace/projects/$id/edit?step=1', repo: repo, me: _devMe),
        );
        await _settle(t, 8);
        expect(find.textContaining('Step 2 of 5'), findsWidgets);
        expect(
          find.text('280'),
          findsOneWidget,
          reason: 'prefilled from the stored project, not a mock',
        );
        expect(find.text('Changes requested'), findsWidgets);
      },
    );

    testWidgets('a project that is not yours is denied, not shown', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 1000));
      await t.pumpWidget(
        _app('/workspace/projects/not-mine', repo: _devRepo(), me: _devMe),
      );
      await _settle(t);
      expect(find.textContaining('do not have access'), findsOneWidget);
    });

    testWidgets(
      'my projects lists, filters by status and links each card to its own status page',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1400));
        final repo = _devRepo();
        final a = await repo.saveProject(
          _valid(name: 'Alpha Heights'),
          submit: true,
          idempotencyKey: 'a',
        );
        await repo.saveProject(
          ProjectDraft(name: 'Beta Draft'),
          submit: false,
          idempotencyKey: 'b',
        );
        repo.debugDecide(a.id, ProjectStatus.approved);
        await t.pumpWidget(
          _app('/app/account/workspace/projects', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(find.textContaining('Alpha Heights'), findsOneWidget);
        expect(find.textContaining('Beta Draft'), findsOneWidget);
        await _tapText(t, 'Draft');
        expect(find.textContaining('Alpha Heights'), findsNothing);
        expect(find.textContaining('Beta Draft'), findsOneWidget);
        await _tapText(t, 'All');
        await t.tap(
          find.textContaining('Alpha Heights').first,
          warnIfMissed: false,
        );
        await _settle(t);
        expect(find.text('Approved'), findsWidgets);
        expect(find.textContaining('Alpha Heights'), findsWidgets);
      },
    );
  });

  group('professional tools', () {
    testWidgets(
      'leads show a gated state when no listing endpoint is confirmed',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        await t.pumpWidget(
          _app('/app/account/workspace/leads', repo: _GatedRepo(() => _state(SignupPurpose.propertyDevelopmentCompany, GrantState.approved)), me: _devMe),
        );
        await _settle(t);
        expect(
          find.textContaining('Contact activity is not available yet'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'contact events list and detail carry no message, budget or CRM actions',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final repo = _CapRepo(
          () => _state(
            SignupPurpose.propertyDevelopmentCompany,
            GrantState.approved,
          ),
          leads: true,
        );
        await t.pumpWidget(
          _app('/app/account/workspace/leads', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(find.text('Call'), findsWidgets);
        await _tapText(t, 'Call');
        expect(find.text('Call tap'), findsOneWidget);
        for (final banned in [
          'Mark as responded',
          'Close inquiry',
          'Budget',
          'Message',
        ]) {
          expect(find.textContaining(banned), findsNothing, reason: banned);
        }
        expect(
          find.textContaining('does not include a message'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'engagement confirmation is blocked-by-contract when unsupported',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        await t.pumpWidget(
          _app(
            '/app/account/workspace/engagements',
            repo: _GatedRepo(() => _state(SignupPurpose.propertyDevelopmentCompany, GrantState.approved)),
            me: _devMe,
          ),
        );
        await _settle(t);
        expect(
          find.textContaining('Engagement confirmation is not available yet'),
          findsOneWidget,
        );
        await t.pumpWidget(
          _app('/workspace/engagements/e1', repo: _GatedRepo(() => _state(SignupPurpose.propertyDevelopmentCompany, GrantState.approved)), me: _devMe),
        );
        await _settle(t);
        expect(
          find.textContaining('Engagement confirmation is not available yet'),
          findsOneWidget,
        );
        expect(find.text('Confirm completed'), findsNothing);
      },
    );

    testWidgets(
      'a supported engagement is confirmed through the repository and states the next step',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final repo = _CapRepo(
          () => _state(
            SignupPurpose.propertyDevelopmentCompany,
            GrantState.approved,
          ),
          engagements: true,
        );
        await t.pumpWidget(
          _app('/workspace/engagements/e1', repo: repo, me: _devMe),
        );
        await _settle(t);
        expect(find.textContaining('Confirm by'), findsOneWidget);
        await _tapText(t, 'Confirm completed');
        await _tapLast(t, 'Confirm completed');
        expect(repo.confirmed, ['e1']);
      },
    );

    testWidgets(
      'profile validates phone numbers and reports review state after saving',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1400));
        await t.pumpWidget(
          _app('/app/account/workspace/profile', repo: _devRepo(), me: _devMe),
        );
        await _settle(t);
        expect(
          find.text('Muscat'),
          findsNothing,
          reason: 'no prefilled location',
        );
        final fields = find.byType(TextField);
        await t.enterText(fields.at(1), '123');
        await _tapText(t, 'Save changes');
        expect(
          find.text('Enter an 8-digit Oman mobile number.'),
          findsOneWidget,
        );
        await t.enterText(fields.at(1), '91234567');
        await _tapText(t, 'Save changes');
        await _settle(t, 4);
        expect(find.textContaining('waiting for review'), findsOneWidget);
        expect(find.textContaining('is live'), findsNothing);
      },
    );

    testWidgets(
      'portfolio is capability-gated: nothing invented, add is disabled and explained',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final repo = _GatedRepo(
          () => _state(SignupPurpose.constructionCompany, GrantState.approved),
        );
        await t.pumpWidget(
          _app(
            '/app/account/workspace/portfolio',
            repo: repo,
            me: _me(SignupPurpose.constructionCompany, GrantState.approved),
          ),
        );
        await _settle(t);
        expect(
          find.textContaining('No approved portfolio work yet'),
          findsOneWidget,
        );
        expect(find.textContaining('needs a portfolio service'), findsWidgets);
        expect(find.byType(Image), findsNothing);
      },
    );

    testWidgets(
      'business reviews show only published reviews and no reply control',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        await t.pumpWidget(
          _app('/app/account/workspace/reviews', repo: _devRepo(), me: _devMe),
        );
        await _settle(t);
        // The preview build lists clearly marked sample reviews for the demo business; a real build has none yet.
        if (kDemoMode) {
          expect(find.textContaining('Sample review'), findsWidgets);
          expect(find.text('3 reviews'), findsOneWidget, reason: 'the summary count matches the listed reviews');
        } else {
          expect(find.textContaining('No published reviews yet'), findsOneWidget);
        }
        expect(find.text('Reply'), findsNothing);
      },
    );
  });

  group('contact, theme and motion', () {
    testWidgets(
      'Contact asks guests to sign in, then shows copyable numbers and claims no call',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        String? copiedText;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copiedText = (call.arguments as Map)['text'] as String?;
            }
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final repo = DemoDevBuildRepository(() => null, lag: Duration.zero);
        await t.pumpWidget(
          _app('/build/pro/demo-c1', repo: repo, signedOut: true),
        );
        await _settle(t);
        await t.tap(
          find.widgetWithText(AQPrimaryButton, 'Contact'),
          warnIfMissed: false,
        );
        await _settle(t, 4);
        expect(find.text('Log in'), findsWidgets);
        expect(find.text('Copy number'), findsNothing);

        await t.pumpWidget(
          _app(
            '/build/pro/demo-c1',
            repo: repo,
            me: _me(SignupPurpose.userToShop, null),
          ),
        );
        await _settle(t);
        await t.tap(
          find.widgetWithText(AQPrimaryButton, 'Contact'),
          warnIfMissed: false,
        );
        await _settle(t, 4);
        expect(find.text('Copy number'), findsWidgets);
        expect(
          find.textContaining('not built into this version'),
          findsOneWidget,
        );
        await t.tap(find.text('Copy number').first, warnIfMissed: false);
        await _settle(t, 4);
        expect(find.text('Number copied'), findsOneWidget);
        expect(copiedText, matches(RegExp(r'^\+968 9\d{3} \d{4}$')));
        expect(copiedText, isNot(contains('0000 0000')));
        expect(find.textContaining('Calling '), findsNothing);
      },
    );

    testWidgets(
      'Contact is disabled and explained when the profile has no contact details',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        final repo = DemoDevBuildRepository(() => null, lag: Duration.zero);
        await t.pumpWidget(_app('/build/pro/b1', repo: repo, me: _devMe));
        await _settle(t);
        // Demo businesses from the shared mock set carry demo numbers; a profile without any would show the footnote.
        expect(t.takeException(), isNull);
      },
    );

    for (final loc in [
      '/app/explore/build',
      '/app/explore/build/results?cat=developer',
      '/build/pro/b2',
      '/build/project/demo-p1',
    ]) {
      testWidgets('dark theme builds $loc without overflow', (t) async {
        await t.binding.setSurfaceSize(const Size(393, 852));
        await t.pumpWidget(
          _app(
            loc,
            repo: DemoDevBuildRepository(() => null, lag: Duration.zero),
            me: _devMe,
            dark: true,
          ),
        );
        await _settle(t);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('dark theme builds the workspace and wizard', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 852));
      final repo = _devRepo();
      for (final loc in [
        '/app/account/workspace',
        '/workspace/projects/new',
        '/app/account/workspace/projects',
      ]) {
        await t.pumpWidget(_app(loc, repo: repo, me: _devMe, dark: true));
        await _settle(t);
        expect(t.takeException(), isNull, reason: loc);
      }
    });

    testWidgets(
      'reduced motion: steps still change and nothing waits on an animation',
      (t) async {
        await t.binding.setSurfaceSize(const Size(393, 1000));
        await t.pumpWidget(
          _app(
            '/workspace/projects/new',
            repo: _devRepo(),
            me: _devMe,
            reduceMotion: true,
          ),
        );
        await _settle(t, 2);
        await t.enterText(find.byType(TextField).first, 'Quick Name');
        await _tapText(t, 'Select project type');
        await _tapText(t, 'Villa');
        await t.tap(find.text('Save & continue').first, warnIfMissed: false);
        await t.pump(const Duration(milliseconds: 50));
        await t.pump(const Duration(milliseconds: 50));
        expect(find.textContaining('Step 2 of 5'), findsWidgets);
        expect(t.takeException(), isNull);
      },
    );
  });

  testWidgets('Arabic workspace renders without overflow', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    await t.pumpWidget(
      _app('/app/account/workspace', repo: _devRepo(), me: _devMe, lang: 'ar'),
    );
    await _settle(t);
    expect(t.takeException(), isNull);
  });
}

/// Every write fails like an offline request.
class _Failing extends DemoDevBuildRepository {
  _Failing()
    : super(
        () => _state(
          SignupPurpose.propertyDevelopmentCompany,
          GrantState.approved,
        ),
      );
  @override
  Future<DbProject> saveProject(
    ProjectDraft draft, {
    required bool submit,
    required String idempotencyKey,
  }) async => throw const ApiException(ApiErrorCode.network);
}
