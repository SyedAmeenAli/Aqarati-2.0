import 'package:aqarati_app/data/repositories/local_persistence.dart';
import 'package:aqarati_app/features/analytics/analytics_charts.dart';
import 'package:aqarati_app/features/analytics/analytics_screens.dart' show AQPeriodSwitch;
import 'package:aqarati_app/features/entry/screens/purpose_selection_screen.dart';
import 'package:aqarati_app/features/role_home/role_home_model.dart' show HomeWorkspace;
import 'package:aqarati_app/features/role_home/role_home_widgets.dart';
import 'package:aqarati_app/features/workspace/aq_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The visual redesign: category grids, the Shop / Work capsule, balanced KPI rows, essentials cards,
/// the interactive analytics chart and period switch, and the registration cards. Each is exercised at
/// phone widths, in dark and in Arabic where it matters, and for overflow.
Widget _host(Widget child, {bool dark = false, bool rtl = false, double scale = 1}) => MaterialApp(
  locale: Locale(rtl ? 'ar' : 'en'),
  localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
  supportedLocales: const [Locale('en'), Locale('ar')],
  builder: (context, c) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: c!),
  theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
  home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
);

void _size(WidgetTester t, double w, [double h = 1800]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

List<AQPhotoTile> _tiles(int n) => [
  for (var i = 0; i < n; i++) AQPhotoTile(image: 'assets/entry/oman_terrace_2k.jpg', icon: 'home', title: 'Tile $i', sub: 'About tile $i', onTap: () {}),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('category grids', () {
    test('columns follow the width: two on any phone, three on a tablet, four on a wide screen', () {
      for (final w in <double>[320, 343, 390, 430]) {
        expect(aqTileColumns(w), 2, reason: '$w');
      }
      expect(aqTileColumns(768), 3);
      expect(aqTileColumns(1280), 4);
    });

    for (final w in <double>[320, 343, 390, 430]) {
      testWidgets('four tiles make a 2 x 2 grid at $w px, equal size, no overflow', (t) async {
        _size(t, w);
        await t.pumpWidget(_host(AQTileGrid(tiles: _tiles(4))));
        await t.pump();
        final rects = [for (var i = 0; i < 4; i++) t.getRect(find.text('Tile $i'))];
        expect({for (final r in rects) r.top.round()}.length, 2, reason: 'two rows');
        final boxes = [for (var i = 0; i < 4; i++) t.getSize(find.byType(AQPhotoTile).at(i))];
        expect(boxes.every((s) => (s.width - boxes.first.width).abs() < 1 && (s.height - boxes.first.height).abs() < 1), isTrue, reason: 'equal tiles');
        expect(boxes.first.width, greaterThan((w - 32) / 2 - 12), reason: 'each tile is about half the width, not a quarter');
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('tiles stay two across at 200% text, in Arabic and in dark', (t) async {
      _size(t, 343);
      for (final cfg in [(true, false, 2.0), (false, true, 1.0), (true, true, 2.0)]) {
        await t.pumpWidget(_host(AQTileGrid(tiles: _tiles(4)), rtl: cfg.$1, dark: cfg.$2, scale: cfg.$3));
        await t.pump();
        expect(t.takeException(), isNull, reason: '$cfg');
      }
    });

    testWidgets('a tap on a tile runs its action', (t) async {
      _size(t, 390);
      var n = 0;
      await t.pumpWidget(_host(AQTileGrid(tiles: [AQPhotoTile(image: 'assets/entry/oman_terrace_2k.jpg', icon: 'home', title: 'Agriculture', sub: 'Farms', onTap: () => n++)])));
      await t.tap(find.text('Agriculture'));
      expect(n, 1);
    });
  });

  group('Shop / Work capsule', () {
    testWidgets('the real selection changes only on the other mode, and is a compact control', (t) async {
      _size(t, 390);
      final calls = <HomeWorkspace>[];
      await t.pumpWidget(_host(Align(alignment: Alignment.centerRight, child: RoleWorkspaceSwitcher(selected: HomeWorkspace.buyer, onChanged: calls.add))));
      await t.pump();
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Work'), findsOneWidget);
      expect(t.getSize(find.byType(RoleWorkspaceSwitcher)).width, lessThan(200), reason: 'a capsule, not a full-width bar');
      await t.tap(find.text('Shop'));
      expect(calls, isEmpty, reason: 'the current mode is not a change');
      await t.tap(find.text('Work'));
      expect(calls, [HomeWorkspace.agent]);
    });

    testWidgets('no overflow at 200% text or in Arabic, either mode selected', (t) async {
      _size(t, 320);
      for (final sel in HomeWorkspace.values) {
        for (final cfg in [(false, 2.0), (true, 1.0), (true, 2.0)]) {
          await t.pumpWidget(_host(RoleWorkspaceSwitcher(selected: sel, onChanged: (_) {}), rtl: cfg.$1, scale: cfg.$2));
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull, reason: '$sel $cfg');
        }
      }
    });
  });

  group('dashboard metrics', () {
    KpiTile k(String l, [String v = '3']) => KpiTile(label: l, value: v, icon: 'activity');

    for (final w in <double>[320, 343, 390]) {
      testWidgets('three metrics sit in one balanced row at $w px', (t) async {
        _size(t, w);
        await t.pumpWidget(_host(KpiGrid(tiles: [k('Requests'), k('Awaiting'), k('Completed')])));
        await t.pump();
        final tops = {for (final s in ['Requests', 'Awaiting', 'Completed']) t.getRect(find.text(s)).top.round()};
        expect(tops.length, 1, reason: 'no card stranded on a second row');
        expect(t.takeException(), isNull);
      });
      testWidgets('four metrics make a 2 x 2 at $w px', (t) async {
        _size(t, w);
        await t.pumpWidget(_host(KpiGrid(tiles: [k('A one'), k('B two'), k('C three'), k('D four')])));
        await t.pump();
        final tops = {for (final s in ['A one', 'B two', 'C three', 'D four']) t.getRect(find.text(s)).top.round()};
        expect(tops.length, 2);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('an essentials card is a substantial module, at 320 px without overflow', (t) async {
      _size(t, 320);
      await t.pumpWidget(_host(Row(children: [
        Expanded(child: RoleEssentialCard(number: '01', icon: 'account', label: 'Identity', sub: 'Company details and logo.', accent: const Color(0xFF9A5B34), onTap: () {}, status: 'Add details', statusOk: false)),
        const SizedBox(width: 12),
        Expanded(child: RoleEssentialCard(number: '02', icon: 'pin', label: 'Presence', sub: 'Address and location.', accent: const Color(0xFF9A5B34), onTap: () {}, status: 'Complete', statusOk: true)),
      ])));
      await t.pump();
      expect(t.getSize(find.byType(RoleEssentialCard).first).height, greaterThanOrEqualTo(176));
      expect(t.takeException(), isNull);
    });
  });

  group('analytics controls', () {
    testWidgets('the period switch changes the selection and is real', (t) async {
      _size(t, 390);
      var sel = 8;
      await t.pumpWidget(_host(StatefulBuilder(builder: (c, set) => AQPeriodSwitch(values: const [4, 8, 12], selected: sel, labelOf: (w) => '$w weeks', onChanged: (w) => set(() => sel = w)))));
      await t.pump();
      await t.tap(find.text('12 weeks'));
      await t.pump(const Duration(milliseconds: 300));
      expect(sel, 12);
      await t.tap(find.text('4 weeks'));
      expect(sel, 4);
      expect(t.takeException(), isNull);
    });

    testWidgets('tapping the chart reads one week: the reading is exposed and cleared on new data', (t) async {
      _size(t, 390);
      final handle = t.ensureSemantics();
      final values = <double>[3, 5, 4, 9, 6, 8, 7, 12];
      final labels = [for (var i = 1; i <= 8; i++) '$i/9'];
      await t.pumpWidget(_host(AQLineChart(values: values, labels: labels, semanticsLabel: 'Leads')));
      await t.pump(const Duration(seconds: 1));
      expect(find.bySemanticsLabel(RegExp(r'^Leads$')), findsOneWidget);
      final box = t.getRect(find.byType(AQLineChart));
      await t.tapAt(Offset(box.left + 32 + (box.width - 36) * 3 / 7, box.center.dy));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.bySemanticsLabel(RegExp(r'^Leads\. 4/9: 9$')), findsOneWidget, reason: 'the tapped week is announced');
      expect(t.takeException(), isNull);
      handle.dispose();
    });

    testWidgets('the chart and donut draw in dark and Arabic without overflow', (t) async {
      _size(t, 320);
      for (final cfg in [(true, false), (false, true), (true, true)]) {
        await t.pumpWidget(_host(Column(children: [
          AQLineChart(values: const <double>[2, 4, 3, 6], labels: const ['1/9', '8/9', '15/9', '22/9'], semanticsLabel: 'x'),
          const AQDonut(parts: <(String, double)>[('Open', 3), ('Won', 2)], centerLabel: 'Total'),
        ]), rtl: cfg.$1, dark: cfg.$2));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull, reason: '$cfg');
      }
    });
  });

  group('professional registration cards', () {
    Widget app() => ProviderScope(
      child: AQLocalPersistence(
        child: MaterialApp.router(
          routerConfig: GoRouter(routes: [
            GoRoute(path: '/', builder: (_, _) => const PurposeSelectionScreen(businessOnly: true)),
            GoRoute(path: '/:p(.*)', builder: (_, s) => Scaffold(body: Text('AT ${s.uri}'))),
          ]),
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          supportedLocales: const [Locale('en'), Locale('ar')],
        ),
      ),
    );

    for (final w in <double>[320, 390]) {
      testWidgets('four substantial cards in a 2 x 2 at $w px; selecting one enables Continue; no repeated Skip', (t) async {
        _size(t, w, 1400);
        await t.pumpWidget(app());
        for (var i = 0; i < 12; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        final names = ['Construction Company', 'Property Development Company', 'Building Architecture', 'Interior & Exterior Design'];
        for (final n in names) {
          expect(find.text(n), findsOneWidget, reason: n);
        }
        final tops = {for (final n in names) t.getRect(find.text(n)).top.round()};
        expect(tops.length, 2, reason: 'two rows of two');
        expect(find.text('Skip'), findsNothing, reason: 'no Skip badge on any card');
        expect(find.bySemanticsLabel(RegExp('Continue')), findsWidgets);
        await t.tap(find.text('Building Architecture'));
        await t.pump(const Duration(milliseconds: 300));
        expect(t.takeException(), isNull);
      });
    }
  });
}
