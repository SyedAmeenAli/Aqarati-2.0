import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/core/theme/app_theme.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/pro/pro_shell.dart';
import 'package:aqarati_app/features/pro/pro_tab_screens.dart';
import 'package:aqarati_app/features/settings/business_settings_screen.dart';
import 'package:aqarati_app/features/settings/settings_screens.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The three families the app bundles. Anything else drawn as text is a fallback to a system font.
const _bundled = {'Fraunces', 'PlusJakartaSans', 'IBMPlexSansArabic'};

bool _hasArabic(String s) => RegExp(r'[؀-ۿݐ-ݿࢠ-ࣿﭐ-﷿ﹰ-﻿]').hasMatch(s);

/// Every paragraph on screen whose effective font would not come from a bundled family: either no
/// family at all (the platform default, Roboto on the web) or, for Arabic text, a chain that never
/// reaches the Arabic family.
List<String> offenders(WidgetTester t) {
  final out = <String>[];
  void visit(RenderObject r) {
    final InlineSpan? span = r is RenderParagraph ? r.text : (r is RenderEditable ? r.text : null);
    if (span != null) {
      final text = span.toPlainText(includePlaceholders: false).trim();
      if (text.isNotEmpty && !_isIconGlyph(span)) {
        final style = span.style;
        final fam = style?.fontFamily;
        final chain = <String>[
          if (fam != null) fam.replaceFirst('packages/', ''),
          ...?style?.fontFamilyFallback,
        ];
        final bundled = fam != null && _bundled.contains(fam.replaceFirst('packages/', ''));
        final reachesArabic = chain.contains('IBMPlexSansArabic');
        if (!bundled) {
          out.add('no bundled family (${fam ?? 'default'}): "$text"');
        } else if (_hasArabic(text) && !reachesArabic) {
          out.add('Arabic text without the Arabic family ($chain): "$text"');
        }
      }
    }
    r.visitChildren(visit);
  }

  visit(t.binding.renderViews.first);
  return out;
}

bool _isIconGlyph(InlineSpan s) {
  final f = s.style?.fontFamily;
  return f != null && (f.contains('MaterialIcons') || f.contains('CupertinoIcons'));
}

Widget host(Widget child, {bool ar = false, SignupPurpose purpose = SignupPurpose.constructionCompany}) => ProviderScope(
  overrides: [
    meProvider.overrideWith((ref) async => MeSession(account: AccountState.active, purpose: purpose, grant: GrantState.approved)),
  ],
  child: MaterialApp(
    theme: AppTheme.light,
    locale: Locale(ar ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: Scaffold(body: child),
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  final screens = <String, Widget Function()>{
    'security': () => const SecuritySettingsScreen(kCustomerSettings),
    'change password': () => const ChangePasswordScreen(kCustomerSettings),
    'appearance': () => const AppearanceSettingsScreen(kCustomerSettings),
    'support form': () => const SupportScreen(kCustomerSettings),
    'language': () => const LanguageSettingsScreen(kCustomerSettings),
    'business settings': () => const BusinessSettingsScreen(role: HomeRole.construction),
    'pro hub': () => const ProMoreScreen(),
    'units': () => const ProUnitsScreen(),
    'projects': () => const ProProjectsScreen(),
    'services': () => const ProServicesScreen(),
  };
  for (final ar in [false, true]) {
    for (final e in screens.entries) {
      testWidgets('${ar ? 'Arabic' : 'English'}: ${e.key} draws only bundled fonts', (t) async {
        t.view.physicalSize = const Size(393, 2400);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(host(e.value(), ar: ar));
        await settle(t);
        expect(offenders(t), isEmpty, reason: e.key);
      });
    }
  }

  testWidgets('control: the audit does flag text that would fall back to a system font', (t) async {
    await t.pumpWidget(host(const Column(children: [
      Text('plain', style: TextStyle(fontFamily: 'Roboto')),
      // Latin primary family with Arabic text is fine while the Arabic family follows it.
      Text('مرحبا', style: TextStyle(fontFamily: 'PlusJakartaSans', fontFamilyFallback: ['IBMPlexSansArabic'])),
      Text('مرحبا', style: TextStyle(fontFamily: 'PlusJakartaSans', fontFamilyFallback: [])),
    ]), ar: true));
    await settle(t);
    expect(offenders(t).length, 2);
  });

  testWidgets('typed text in fields draws bundled fonts, English and Arabic', (t) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final ar in [false, true]) {
      await t.pumpWidget(host(const Padding(padding: EdgeInsets.all(16), child: TextField(decoration: InputDecoration(labelText: 'x'))), ar: ar));
      await t.enterText(find.byType(TextField), ar ? 'مرحبا abc 123' : 'Hello مرحبا 123');
      await settle(t);
      expect(offenders(t), isEmpty, reason: 'field ${ar ? 'ar' : 'en'}');
    }
  });

  testWidgets('a dialog and its buttons draw only bundled fonts', (t) async {
    t.view.physicalSize = const Size(393, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    for (final ar in [false, true]) {
      await t.pumpWidget(host(Builder(builder: (c) => TextButton(onPressed: () => showDialog<void>(context: c, builder: (_) => AlertDialog(title: Text(ar ? 'تأكيد' : 'Confirm'), content: Text(ar ? 'هل أنت متأكد؟' : 'Are you sure?'), actions: [TextButton(onPressed: () {}, child: Text(ar ? 'إلغاء' : 'Cancel'))])), child: Text(ar ? 'افتح' : 'Open'))), ar: ar));
      await t.tap(find.byType(TextButton));
      await settle(t);
      expect(offenders(t), isEmpty, reason: 'dialog ${ar ? 'ar' : 'en'}');
      Navigator.of(t.element(find.byType(AlertDialog))).pop();
      await settle(t);
    }
  });
}
