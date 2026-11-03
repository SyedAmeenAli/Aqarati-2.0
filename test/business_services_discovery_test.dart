import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/demo/demo_backend.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart';
import 'package:aqarati_app/features/devbuild/db_profile.dart' show showDbContactSheet;
import 'package:aqarati_app/features/devbuild/db_repository.dart';
import 'package:aqarati_app/features/devbuild/db_routes.dart';
import 'package:aqarati_app/features/devbuild/db_widgets.dart' show dbCategoryLabel, dbProLabel;
import 'package:aqarati_app/core/localization/flow_strings.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/settings/business_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

DemoDevBuildRepository repo({Set<String> Function()? own, SignupPurpose? purpose}) => DemoDevBuildRepository(
  () => purpose == null
      ? null
      : (DemoBackendState()
          ..purpose = purpose
          ..grant = GrantState.approved
          ..account = AccountState.active
          ..businessName = 'Test Business'),
  lag: Duration.zero,
  ownServices: own,
);

Future<List<DbProfessional>> find_(DemoDevBuildRepository r, DbQuery q) async => (await r.professionals(q, limit: 50)).items;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 300));
  }
}

Widget routed(String location, {DevBuildRepository? r, String lang = 'en'}) => ProviderScope(
  overrides: [if (r != null) devBuildRepositoryProvider.overrideWithValue(r)],
  child: MaterialApp.router(
    locale: Locale(lang),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    routerConfig: GoRouter(
      initialLocation: location,
      routes: [
        ShellRoute(builder: (c, s, child) => Scaffold(body: child), routes: [...dbShellRoutes(), ...dbProShellRoutes()]),
        ...dbStandaloneRoutes(),
      ],
    ),
  ),
);

void main() {
  group('one business, several service categories', () {
    test('a construction company that also designs interiors is one record, listed under both categories', () async {
      final r = repo();
      final construction = await find_(r, const DbQuery(type: ProType.construction));
      final interior = await find_(r, const DbQuery(type: ProType.interiorExterior));
      expect(construction.map((p) => p.id), contains('demo-c1'));
      expect(interior.map((p) => p.id), contains('demo-c1'), reason: 'discoverable as interior design too');
      final everyone = await find_(r, const DbQuery());
      expect(everyone.where((p) => p.id == 'demo-c1'), hasLength(1), reason: 'never duplicated across categories');
      final c1 = (await r.professional('demo-c1'))!;
      expect(c1.type, ProType.construction, reason: 'the primary role does not change');
      expect(c1.extraTypes, [ProType.interiorExterior]);
      expect(c1.allTypes, [ProType.construction, ProType.interiorExterior]);
      expect(c1.designService, InteriorExteriorServiceType.interior);
    });

    test('a record that already carries several categories becomes one business with additional services', () async {
      final r = repo();
      final b2 = (await r.professional('b2'))!;
      expect(b2.name, 'Namaa Construction');
      expect(b2.allTypes, containsAll([ProType.developer, ProType.construction]));
      final construction = await find_(r, const DbQuery(type: ProType.construction));
      expect(construction.map((p) => p.id), contains('b2'));
      expect((await find_(r, const DbQuery())).where((p) => p.id == 'b2'), hasLength(1));
    });

    test('the interior and exterior filter reaches the additional service, and only the side offered', () async {
      final r = repo();
      final interior = await find_(r, const DbQuery(type: ProType.interiorExterior, serviceType: InteriorExteriorServiceType.interior));
      expect(interior.map((p) => p.id), contains('demo-c1'));
      final exterior = await find_(r, const DbQuery(type: ProType.interiorExterior, serviceType: InteriorExteriorServiceType.exterior));
      expect(exterior.map((p) => p.id), isNot(contains('demo-c1')));
    });

    test('a business is not listed in a category it does not offer', () async {
      final r = repo();
      final architecture = await find_(r, const DbQuery(type: ProType.architecture));
      expect(architecture.map((p) => p.id), isNot(contains('demo-c1')));
      final developers = await find_(r, const DbQuery(type: ProType.developer));
      expect(developers.map((p) => p.id), isNot(contains('demo-c1')));
    });

    test('a developer that also builds appears under construction; the developer rule still holds under developers', () async {
      final r = repo();
      final construction = await find_(r, const DbQuery(type: ProType.construction));
      expect(construction.map((p) => p.id), contains('demo-d1'));
      final developers = await find_(r, const DbQuery(type: ProType.developer));
      expect(developers.map((p) => p.id), contains('demo-d1'));
    });

    test('text search still finds the business through any category', () async {
      final r = repo();
      final hits = await find_(r, const DbQuery(type: ProType.interiorExterior, text: 'sahari'));
      expect(hits.map((p) => p.id), ['demo-c1']);
    });

    test('settings services map to directory categories; brokerage and maintenance are not directory categories', () {
      final m = proTypesOfServices({'brokerage', 'maintenance', 'interior', 'exterior', 'architecture'}, primary: ProType.construction);
      expect(m.types, [ProType.architecture, ProType.interiorExterior]);
      expect(m.design, InteriorExteriorServiceType.both);
      expect(proTypesOfServices({'construction'}, primary: ProType.construction).types, isEmpty, reason: 'the primary role is not repeated');
    });

    test('the signed-in business\'s own additional services reach its organisation record', () async {
      final services = <String>{};
      final r = repo(own: () => services, purpose: SignupPurpose.constructionCompany);
      expect((await r.myOrganisation())!.extraTypes, isEmpty);
      services.addAll({'interior', 'architecture'});
      final org = (await r.myOrganisation())!;
      expect(org.type, ProType.construction);
      expect(org.extraTypes, [ProType.architecture, ProType.interiorExterior]);
      expect(org.designService, InteriorExteriorServiceType.interior);
    });

    test('business settings keep one account: toggling a service changes the same record', () {
      final box = ProviderContainer();
      addTearDown(box.dispose);
      box.read(businessProfileProvider.notifier).toggleService('interior');
      expect(box.read(businessProfileProvider).services, {'interior'});
      expect(box.read(businessProfileProvider).name, 'Demo business');
      box.read(businessProfileProvider.notifier).toggleService('interior');
      expect(box.read(businessProfileProvider).services, isEmpty);
    });

    test('labels name the primary role first and the additional services after it, in both languages', () async {
      final c1 = (await repo().professional('demo-c1'))!;
      expect(dbProLabel(const FlowStrings.forTest(false), c1), 'Construction Company · also Interior design');
      expect(dbCategoryLabel(const FlowStrings.forTest(true), c1, ProType.interiorExterior), 'التصميم الداخلي');
      expect(dbProLabel(const FlowStrings.forTest(true), c1), contains('ويقدّم أيضاً'));
    });
  });

  group('public profile and enquiry context', () {
    testWidgets('the profile lists every service category, marks the primary one, and says it is one business', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(routed('/build/pro/demo-c1', r: repo()));
      await settle(t);
      expect(find.text('Service categories'), findsOneWidget);
      expect(find.text('Construction Company · Primary'), findsOneWidget);
      final tags = find.byKey(const ValueKey('db-service-tags'));
      expect(find.descendant(of: tags, matching: find.text('Interior design')), findsOneWidget);
      expect(find.text('Also offers'), findsOneWidget, reason: 'the identity block names the additional service once');
      expect(find.text('One business, listed in each category it offers.'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('a business with no additional service shows no "one business" note', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(routed('/build/pro/demo-i1', r: repo()));
      await settle(t);
      expect(find.text('One business, listed in each category it offers.'), findsNothing);
    });

    testWidgets('the profile in Arabic lists the categories in Arabic and mirrors', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 1800));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(routed('/build/pro/demo-c1', r: repo(), lang: 'ar'));
      await settle(t);
      expect(find.text('فئات الخدمات'), findsOneWidget);
      expect(find.descendant(of: find.byKey(const ValueKey('db-service-tags')), matching: find.text('التصميم الداخلي')), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('an enquiry opened from the interior category names that service', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 1200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      final b2 = (await repo().professional('demo-c1'))!;
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
          home: Consumer(
            builder: (c, ref, _) => Scaffold(
              body: TextButton(onPressed: () => showDbContactSheet(c, ref, b2, about: ProType.interiorExterior), child: const Text('open')),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      await settle(t);
      expect(find.byKey(const ValueKey('db-enquiry-about')), findsOneWidget);
      expect(find.text('Enquiry about: Interior design'), findsOneWidget);
    });

    testWidgets('a result opened from the interior category carries that service into the profile address', (t) async {
      await t.binding.setSurfaceSize(const Size(393, 2200));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(routed('/app/explore/build/results?cat=interiorExterior', r: repo()));
      await settle(t);
      expect(find.textContaining('Sahari Contracting'), findsOneWidget, reason: 'listed under interior design');
      expect(find.textContaining('also Interior design'), findsOneWidget, reason: 'the card names the additional service');
      await t.tap(find.textContaining('Sahari Contracting'));
      await settle(t);
      expect(find.text('Service categories'), findsOneWidget, reason: 'its profile opened');
      expect(t.takeException(), isNull);
    });
  });
}
