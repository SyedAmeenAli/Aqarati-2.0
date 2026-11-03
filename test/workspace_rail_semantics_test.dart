import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/core/localization/flow_strings.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _roles = {
  SignupPurpose.propertyDevelopmentCompany: HomeRole.developer,
  SignupPurpose.constructionCompany: HomeRole.construction,
  SignupPurpose.buildingArchitecture: HomeRole.architecture,
  SignupPurpose.interiorExteriorDesign: HomeRole.interiorExterior,
};

Widget app(SignupPurpose p, {bool ar = false}) => ProviderScope(
  overrides: [meProvider.overrideWith((ref) async => MeSession(account: AccountState.active, purpose: p, grant: GrantState.approved))],
  child: MaterialApp.router(
    locale: Locale(ar ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    routerConfig: GoRouter(
      initialLocation: '/pro',
      routes: [
        ShellRoute(builder: (c, s, child) => ProShell(child: child), routes: [GoRoute(path: '/pro', builder: (_, _) => const Text('PRO HOME'))]),
      ],
    ),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  for (final e in _roles.entries) {
    testWidgets('${e.key.name}: on a wide screen the side rail is exposed to assistive technology, all six destinations', (t) async {
      final handle = t.ensureSemantics();
      t.view.physicalSize = const Size(1280, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(app(e.key));
      await settle(t);
      final labels = [for (final tab in proTabsFor(e.value)) tab.labelKey];
      expect(labels.length, 6);
      final seen = t.semantics.simulatedAccessibilityTraversal().map((n) => n.label).toList();
      for (final key in labels) {
        expect(seen, contains(const FlowStrings.forTest(false).t(key)), reason: '${e.key.name} $key in $seen');
      }
      handle.dispose();
    });
  }

  testWidgets('Arabic: the rail sits at the right edge and its separator on the left of the rail', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(SignupPurpose.constructionCompany, ar: true));
    await settle(t);
    expect(t.getTopRight(find.text('AQARATI')).dx, greaterThan(1280 - 232), reason: 'the rail is on the right in Arabic');
    expect(t.getTopLeft(find.text('PRO HOME')).dx, lessThan(1280 - 232), reason: 'the page is to its left');
    expect(t.takeException(), isNull);
  });

  testWidgets('English: the rail is at the left edge', (t) async {
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(app(SignupPurpose.constructionCompany));
    await settle(t);
    expect(t.getTopLeft(find.text('AQARATI')).dx, lessThan(232));
    expect(t.getTopLeft(find.text('PRO HOME')).dx, greaterThan(232 - 1));
  });
}
