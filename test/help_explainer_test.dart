import 'package:aqarati_app/core/aq/aq_help.dart';
import 'package:aqarati_app/features/search/aq_properties_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child, {bool rtl = false}) => ProviderScope(
  child: MaterialApp(
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    home: Scaffold(body: child),
  ),
);

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('the ? on Properties opens the explainer and closing returns to Properties', (
    t,
  ) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const AQPropertiesHubScreen()));
    await _settle(t);
    expect(find.byType(AQHelpButton), findsOneWidget);
    await t.ensureVisible(find.byType(AQHelpButton));
    await _settle(t);
    await t.tap(find.byType(AQHelpButton));
    await _settle(t);
    expect(find.text('Real estate on AQARATI'), findsOneWidget);
    expect(find.textContaining('not legal advice'), findsOneWidget);
    for (final w in ['Buy', 'Rent', 'Sell', 'Kinds of property']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
    await t.tap(find.text('Got it'));
    await _settle(t);
    expect(find.text('Real estate on AQARATI'), findsNothing);
    expect(find.byType(AQPropertiesHubScreen), findsOneWidget);
    expect(find.text('Browse Properties'), findsOneWidget);
  });

  testWidgets('it is a labelled button for assistive technology', (t) async {
    final h = t.ensureSemantics();
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const AQPropertiesHubScreen()));
    await _settle(t);
    expect(
      find.bySemanticsLabel('Help: what does real estate mean here?'),
      findsOneWidget,
    );
    h.dispose();
  });

  testWidgets('Arabic and RTL: opens, reads and closes', (t) async {
    await t.binding.setSurfaceSize(const Size(360, 740));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(_app(const AQPropertiesHubScreen(), rtl: true));
    await _settle(t);
    // The six-module grid pushes the Browse Properties header (and its ?) below the first screen.
    await t.ensureVisible(find.byType(AQHelpButton));
    await _settle(t);
    await t.tap(find.byType(AQHelpButton));
    await _settle(t);
    expect(find.text('العقارات في عقاراتي'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.tap(find.text('فهمت'));
    await _settle(t);
    expect(find.text('العقارات في عقاراتي'), findsNothing);
  });

  testWidgets('large text does not overflow the sheet', (t) async {
    await t.binding.setSurfaceSize(const Size(393, 852));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(393, 852),
              textScaler: TextScaler.linear(2),
            ),
            child: const Scaffold(body: Center(child: AQHelpButton())),
          ),
        ),
      ),
    );
    await t.tap(find.byType(AQHelpButton));
    await _settle(t);
    expect(find.text('Got it'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
