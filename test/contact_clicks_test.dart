import 'package:aqarati_app/features/contact/contact_actions.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart';
import 'package:aqarati_app/features/analytics/analytics_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {double width = 375}) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: MediaQuery(data: MediaQueryData(size: Size(width, 900)), child: Scaffold(body: SingleChildScrollView(child: child))),
      ),
    );

void main() {
  for (final w in [320.0, 375.0]) {
    testWidgets('In-app chat, Call and WhatsApp show without overflow at ${w.toInt()} px', (t) async {
      t.view.physicalSize = Size(w, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_app(const Padding(padding: EdgeInsets.all(24), child: AQContactButtons(name: 'Rawaq', phone: '+968 9123 4567')), width: w));
      await t.pump();
      expect(find.text('Call'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      expect(find.text('Message in the app'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('without a phone number Call and WhatsApp are off but Chat still works', (t) async {
    await t.pumpWidget(_app(const Padding(padding: EdgeInsets.all(24), child: AQContactButtons(name: 'Rawaq'))));
    await t.pump();
    await t.tap(find.text('Message in the app'));
    await t.pumpAndSettle();
    expect(find.text('Chat with Rawaq'), findsOneWidget);
    expect(find.textContaining('not sent'), findsOneWidget, reason: 'the demo chat says nothing leaves the screen');
  });

  testWidgets('the demo chat shows what you type on the same screen', (t) async {
    await t.pumpWidget(_app(const Padding(padding: EdgeInsets.all(24), child: AQContactButtons(name: 'Rawaq', subject: 'Villa'))));
    await t.pump();
    await t.tap(find.text('Message in the app'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Is it still available?');
    await t.tap(find.bySemanticsLabel('Send message'));
    await t.pump();
    expect(find.text('Is it still available?'), findsOneWidget);
    // The demo business answers a moment later, in the same conversation.
    await t.pump(const Duration(milliseconds: 1500));
    expect(find.textContaining('demo reply'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  test('a sample number is stable and clearly Omani-formatted', () {
    expect(aqDemoPhoneFor('b4'), aqDemoPhoneFor('b4'));
    expect(aqDemoPhoneFor('b4'), startsWith('+968 9'));
  });

  testWidgets('Analytics offers a Clicks metric for every workspace role', (t) async {
    for (final role in [HomeRole.agent, HomeRole.developer, HomeRole.construction, HomeRole.architecture, HomeRole.interiorExterior]) {
      t.view.physicalSize = const Size(393, 2400);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: Scaffold(body: RoleAnalyticsScreen(role: role)),
        ),
      ));
      for (var i = 0; i < 4; i++) {
        await t.pump(const Duration(milliseconds: 300));
      }
      expect(find.text('Clicks by week'), findsWidgets, reason: role.name);
      expect(t.takeException(), isNull, reason: role.name);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the Chats list is empty at first and shows a conversation once you have typed in it', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [chatThreadsProvider.overrideWith((ref) => const [])],
      child: MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: const Scaffold(body: ChatsView()),
      ),
    ));
    await t.pump();
    expect(find.text('No chats yet'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(ProviderScope(
      overrides: [chatThreadsProvider.overrideWith((ref) => const [ChatThread('Rawaq', 'Villa', [ChatMsg('Is it available?', true)])])],
      child: MaterialApp(
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        supportedLocales: const [Locale('en'), Locale('ar')],
        home: const Scaffold(body: ChatsView()),
      ),
    ));
    await t.pump();
    expect(find.text('Rawaq'), findsOneWidget);
    expect(find.text('Is it available?'), findsOneWidget);
    await t.tap(find.text('Rawaq'));
    await t.pumpAndSettle();
    expect(find.text('Chat with Rawaq'), findsOneWidget);
  });

  testWidgets('the inbox starts with two sample conversations', (t) async {
    await t.pumpWidget(_app(const SizedBox(height: 700, child: ChatsView())));
    await t.pump();
    expect(find.text('Rawaq Maintenance Services'), findsOneWidget);
    expect(find.text('Wadi Architecture'), findsOneWidget);
  });
}
