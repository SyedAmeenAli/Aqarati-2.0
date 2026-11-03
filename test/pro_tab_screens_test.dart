import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart';
import 'package:aqarati_app/features/pro/pro_tab_screens.dart';
import 'package:aqarati_app/features/settings/business_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(Widget child, SignupPurpose p, {bool ar = false}) => ProviderScope(
  overrides: [meProvider.overrideWith((ref) async => MeSession(account: AccountState.active, purpose: p, grant: GrantState.approved))],
  child: MaterialApp(
    locale: Locale(ar ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: Scaffold(body: child),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void phone(WidgetTester t, [double w = 393]) {
  t.view.physicalSize = Size(w, 2000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  testWidgets('Units: stock totals add up and every project shows its own line', (t) async {
    phone(t);
    await t.pumpWidget(app(const ProUnitsScreen(), SignupPurpose.propertyDevelopmentCompany));
    await settle(t);
    expect(find.text('Units by project'), findsOneWidget);
    expect(find.text('70'), findsOneWidget, reason: '12 + 18 + 40 units');
    expect(find.text('36'), findsOneWidget, reason: '5 + 9 + 22 available');
    expect(find.text('15'), findsOneWidget, reason: '3 + 4 + 8 reserved');
    expect(find.textContaining('Al Mouj Residences'), findsOneWidget);
    expect(find.textContaining('Barka Gardens'), findsOneWidget);
    expect(find.textContaining('Sample data'), findsOneWidget);
  });

  for (final e in {SignupPurpose.constructionCompany: 'Active projects', SignupPurpose.buildingArchitecture: 'Design projects'}.entries) {
    testWidgets('Projects for ${e.key.name}: its own title, stages and progress, labelled as sample', (t) async {
      phone(t);
      await t.pumpWidget(app(const ProProjectsScreen(), e.key));
      await settle(t);
      expect(find.text(e.value), findsOneWidget);
      expect(find.text('In progress'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
      expect(find.textContaining('Sample data'), findsOneWidget);
    });
  }

  testWidgets('Services: one business, extra services change the Explore categories it appears in', (t) async {
    phone(t);
    await t.pumpWidget(app(const ProServicesScreen(), SignupPurpose.constructionCompany));
    await settle(t);
    final cats = find.byKey(const ValueKey('pro-explore-categories'));
    expect(find.descendant(of: cats, matching: find.text('Construction Company')), findsOneWidget);
    expect(find.descendant(of: cats, matching: find.text('Interior design')), findsNothing);
    await t.tap(find.text('Interior design').first);
    await settle(t);
    expect(find.descendant(of: cats, matching: find.text('Interior design')), findsOneWidget, reason: 'now also listed as interior design');
    expect(find.descendant(of: cats, matching: find.text('Construction Company')), findsOneWidget, reason: 'the primary role stays');
    // The primary service is not offered as an extra to switch off.
    expect(find.text('Business settings'), findsWidgets);
    expect(find.textContaining('Nothing is published'), findsOneWidget);
  });

  testWidgets('Services in Arabic: Arabic category names, no overflow at 320', (t) async {
    phone(t, 320);
    await t.pumpWidget(app(const ProServicesScreen(), SignupPurpose.interiorExteriorDesign, ar: true));
    await settle(t);
    expect(find.text('خدماتك'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('the hub is "More" on a phone, with Analytics and the destinations that are not tabs', (t) async {
    phone(t);
    for (final (p, marker) in [
      (SignupPurpose.propertyDevelopmentCompany, 'Business settings'),
      (SignupPurpose.constructionCompany, 'Portfolio'),
      (SignupPurpose.buildingArchitecture, 'Engagements'),
      (SignupPurpose.interiorExteriorDesign, 'Projects'),
    ]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(const ProMoreScreen(), p));
      await settle(t);
      expect(find.text('More'), findsWidgets, reason: p.name);
      expect(find.text('Analytics'), findsOneWidget, reason: '${p.name} reaches Analytics from More');
      expect(find.text(marker), findsWidgets, reason: '${p.name} $marker');
    }
  });

  testWidgets('on a wide screen the hub carries its own role name', (t) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final (p, title) in [(SignupPurpose.constructionCompany, 'Company'), (SignupPurpose.buildingArchitecture, 'Profile')]) {
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(app(const ProMoreScreen(), p));
      await settle(t);
      expect(find.text(title), findsWidgets, reason: p.name);
    }
  });

  test('every role keeps a default business record: toggling an extra service never creates a second account', () {
    final box = ProviderContainer();
    addTearDown(box.dispose);
    final n = box.read(businessProfileProvider.notifier);
    n.toggleService('architecture');
    n.toggleService('interior');
    expect(box.read(businessProfileProvider).services, {'architecture', 'interior'});
    expect(box.read(businessProfileProvider).name, 'Demo business');
  });
}
