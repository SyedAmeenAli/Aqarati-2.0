import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/core/localization/analytics_strings.dart';
import 'package:aqarati_app/core/localization/entry_strings.dart' show localeProvider, themeModeProvider;
import 'package:aqarati_app/core/localization/settings_strings.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:aqarati_app/features/settings/app_settings.dart';
import 'package:aqarati_app/features/settings/business_settings_screen.dart';
import 'package:aqarati_app/features/settings/settings_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

late ProviderContainer box;

Widget app(Widget child, {bool rtl = false, bool dark = false, double scale = 1}) => ProviderScope(
  overrides: [
    meProvider.overrideWith((ref) async => const MeSession(account: AccountState.active, purpose: SignupPurpose.userToShop)),
  ],
  child: Consumer(
    builder: (context, ref, _) {
      box = ProviderScope.containerOf(context);
      return MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        locale: Locale(rtl ? 'ar' : 'en'),
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
        home: Scaffold(body: child),
      );
    },
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void phone(WidgetTester t, {double w = 393, double h = 2400}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('copy', () {
    test('every settings and analytics string has English and Arabic text', () {
      for (final m in [settingsStrings, analyticsStrings]) {
        for (final e in m.entries) {
          expect(e.value.$1.trim(), isNotEmpty, reason: '${e.key} en');
          expect(e.value.$2.trim(), isNotEmpty, reason: '${e.key} ar');
        }
      }
    });
  });

  group('stored settings', () {
    test('survive a round trip and ignore a damaged value', () {
      const s = AppSettings(textScale: 1.15, reducedMotion: true, locations: {'Muscat'});
      final back = AppSettings.fromJson(s.toJson());
      expect(back.textScale, 1.15);
      expect(back.reducedMotion, isTrue);
      expect(back.locations, {'Muscat'});
      expect(back.notifications['viewings'], isTrue);
      expect(AppSettings.fromJson('{not json').textScale, 1);
      expect(AppSettings.fromJson('{"textScale": 9}').textScale, 1, reason: 'only the offered sizes');
    });
  });

  group('customer pages', () {
    for (final name in kSettingsPages) {
      for (final (w, rtl, dark, scale) in [(320.0, false, false, 1.0), (393.0, true, true, 1.0), (1280.0, false, false, 1.0), (360.0, false, false, 1.6)]) {
        testWidgets('$name renders at ${w.toInt()} px (rtl=$rtl dark=$dark text x$scale)', (t) async {
          phone(t, w: w, h: 2600);
          await t.pumpWidget(app(settingsPageFor(name, kCustomerSettings), rtl: rtl, dark: dark, scale: scale));
          await settle(t);
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('password: each rule is explained, and success is honest about the prototype', (t) async {
      phone(t);
      await t.pumpWidget(app(const ChangePasswordScreen(kCustomerSettings)));
      await settle(t);
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(find.text('Enter your current password.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Current password'), 'oldpass1');
      await t.enterText(find.widgetWithText(TextField, 'New password'), 'longenough');
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(find.text('Include at least one number.'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'New password'), 'longenough1');
      await t.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'different1');
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(find.text('The two passwords do not match.'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'longenough1');
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(find.textContaining('no password was changed'), findsOneWidget);
      expect(find.byKey(const ValueKey('password-simulated')), findsOneWidget);
      expect(find.text('Simulated confirmation'), findsOneWidget);
      expect(find.text('Back to Account and security'), findsOneWidget);
    });

    testWidgets('password: requirements tick live and the visibility toggles reveal the entry', (t) async {
      phone(t);
      await t.pumpWidget(app(const ChangePasswordScreen(kCustomerSettings)));
      await settle(t);
      expect(find.byKey(const ValueKey('password-rules')), findsOneWidget);
      Finder rule(String text, String state) => find.bySemanticsLabel('$text: $state');
      expect(rule('At least 8 characters', 'not met yet'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Current password'), 'oldpass1');
      await t.enterText(find.widgetWithText(TextField, 'New password'), 'longenough1');
      await t.pump();
      expect(rule('At least 8 characters', 'met'), findsOneWidget);
      expect(rule('Includes a number', 'met'), findsOneWidget);
      expect(rule('Different from the current password', 'met'), findsOneWidget);
      expect(rule('Matches the confirmation', 'not met yet'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'longenough1');
      await t.pump();
      expect(rule('Matches the confirmation', 'met'), findsOneWidget);
      // Three entries start obscured; each has its own show control.
      expect(find.bySemanticsLabel('Show password'), findsNWidgets(3));
      await t.tap(find.bySemanticsLabel('Show password').first);
      await t.pump();
      expect(find.bySemanticsLabel('Hide password'), findsOneWidget);
      expect(find.bySemanticsLabel('Show password'), findsNWidgets(2));
      // The page states plainly that nothing is sent anywhere.
      expect(find.textContaining('no password is changed'), findsOneWidget);
    });

    testWidgets('password: the same password as the current one is refused', (t) async {
      phone(t);
      await t.pumpWidget(app(const ChangePasswordScreen(kCustomerSettings)));
      await settle(t);
      await t.enterText(find.widgetWithText(TextField, 'Current password'), 'samepass1');
      await t.enterText(find.widgetWithText(TextField, 'New password'), 'samepass1');
      await t.enterText(find.widgetWithText(TextField, 'Confirm new password'), 'samepass1');
      await t.tap(find.text('Update password'));
      await settle(t);
      expect(find.text('Choose a password different from the current one.'), findsOneWidget);
      expect(find.byKey(const ValueKey('password-simulated')), findsNothing);
    });

    testWidgets('security: the password control opens the password page', (t) async {
      phone(t);
      await t.pumpWidget(app(const SecuritySettingsScreen(kCustomerSettings)));
      await settle(t);
      expect(find.text('Change password'), findsWidgets);
      expect(find.text('Update password'), findsNothing);
    });

    testWidgets('notifications: a category can be switched; email and push say they are not connected', (t) async {
      phone(t);
      await t.pumpWidget(app(const NotificationSettingsScreen(kCustomerSettings)));
      await settle(t);
      expect(box.read(appSettingsProvider).notifications['offers'], isFalse);
      await t.tap(find.text('Offers and news'));
      await settle(t);
      expect(box.read(appSettingsProvider).notifications['offers'], isTrue);
      expect(find.text('Not connected yet'), findsNWidgets(2));
    });

    testWidgets('appearance: theme, text size and reduced motion are set in the app state', (t) async {
      phone(t);
      await t.pumpWidget(app(const AppearanceSettingsScreen(kCustomerSettings)));
      await settle(t);
      await t.tap(find.text('Dark'));
      await t.tap(find.text('Large'));
      await t.tap(find.text('Reduce motion'));
      await settle(t);
      expect(box.read(themeModeProvider), ThemeMode.dark);
      expect(box.read(appSettingsProvider).textScale, 1.15);
      expect(box.read(appSettingsProvider).reducedMotion, isTrue);
    });

    testWidgets('language: Arabic switches the app language', (t) async {
      phone(t);
      await t.pumpWidget(app(const LanguageSettingsScreen(kCustomerSettings)));
      await settle(t);
      await t.tap(find.text('العربية'));
      await settle(t);
      expect(box.read(localeProvider).languageCode, 'ar');
      expect(find.text('+968'), findsOneWidget);
    });

    testWidgets('support: a message needs a subject and text, and is saved with a prototype reference', (t) async {
      phone(t);
      await t.pumpWidget(app(const SupportScreen(kCustomerSettings)));
      await settle(t);
      await t.ensureVisible(find.text('Save message'));
      await t.tap(find.text('Save message'));
      await settle(t);
      expect(find.text('Enter a subject.'), findsOneWidget);
      await t.enterText(find.widgetWithText(TextField, 'Subject'), 'Photos missing');
      await t.enterText(find.widgetWithText(TextField, 'Message'), 'The gallery of one villa has no pictures.');
      await t.tap(find.text('Save message'));
      await settle(t);
      expect(find.textContaining('PROTO-1001'), findsWidgets);
      expect(find.textContaining('Nothing was sent to a person'), findsOneWidget);
      expect(box.read(supportTicketsProvider), hasLength(1));
    });
  });

  group('business settings', () {
    for (final role in [HomeRole.agent, HomeRole.developer, HomeRole.construction, HomeRole.architecture, HomeRole.interiorExterior]) {
      testWidgets('${role.name}: own role fields, fixed primary role, no overflow', (t) async {
        for (final (w, rtl) in [(390.0, false), (1280.0, false), (360.0, true)]) {
          phone(t, w: w, h: 3200);
          await t.pumpWidget(app(BusinessSettingsScreen(role: role), rtl: rtl));
          await settle(t);
          expect(t.takeException(), isNull, reason: '${role.name} @$w');
        }
        await t.pumpWidget(app(BusinessSettingsScreen(role: role)));
        await settle(t);
        for (final e in roleFields(role)) {
          expect(find.text(settingsStrings[e.$2]!.$1), findsWidgets, reason: e.$2);
        }
        final foreign = {
          HomeRole.architecture: 'Contractor grade',
          HomeRole.construction: 'Practice licence',
        };
        final other = foreign[role];
        if (other != null) expect(find.text(other), findsNothing, reason: 'no fields of another role');
      });
    }

    testWidgets('an additional service stays on the same account and is never the primary role', (t) async {
      phone(t, h: 3200);
      await t.pumpWidget(app(const BusinessSettingsScreen(role: HomeRole.construction)));
      await settle(t);
      expect(box.read(businessProfileProvider).services, isEmpty);
      await t.ensureVisible(find.text('Interior design'));
      await t.tap(find.text('Interior design'));
      await settle(t);
      expect(box.read(businessProfileProvider).services, {'interior'});
      // The primary service is not offered again as an extra.
      expect(find.text('Construction'), findsOneWidget, reason: 'shown once, as the primary role');
      expect(primaryServiceOf(HomeRole.construction), 'construction');
    });
  });
}
