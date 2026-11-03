import 'dart:typed_data';

import 'package:aqarati_app/core/aq/aq_glass.dart';
import 'package:aqarati_app/data/api/account_api.dart' show PickedDocument;
import 'package:aqarati_app/features/flow/state/document_state.dart';
import 'package:aqarati_app/features/media/aq_media.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The glass material and the one media system (field, sheet, editor, frames), for every kind of picture.
const _png = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xCF, 0xC0, 0xF0, 0x1F, 0x00, 0x05, 0x00, 0x01, 0xFF, 0x89, 0x99, 0x3D, 0x1D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45,
  0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
];

class _Picker implements DocumentPicker {
  final Uint8List? bytes;
  _Picker(this.bytes);
  @override
  Future<PickedDocument?> pick() async => bytes == null ? null : PickedDocument(name: 'x.png', sizeBytes: bytes!.length, bytes: bytes!);
}

Widget _host(Widget child, {List<Override> overrides = const [], bool dark = false, bool rtl = false, bool highContrast = false, double scale = 1}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    locale: Locale(rtl ? 'ar' : 'en'),
    localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('ar')],
    builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(highContrast: highContrast, textScaler: TextScaler.linear(scale)), child: w!),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
  ),
);

void _size(WidgetTester t, double w, [double h = 1800]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

List<Override> _pick(List<int>? b) => [documentPickerProvider.overrideWithValue(_Picker(b == null ? null : Uint8List.fromList(b)))];

void main() {
  group('glass material', () {
    testWidgets('frosted: a real blur behind a warm translucent fill', (t) async {
      _size(t, 390);
      await t.pumpWidget(_host(const AQGlass(child: SizedBox(width: 100, height: 40))));
      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('high contrast and opaque turn it into a solid surface with no blur', (t) async {
      _size(t, 390);
      await t.pumpWidget(_host(const AQGlass(child: SizedBox(width: 100, height: 40)), highContrast: true));
      expect(find.byType(BackdropFilter), findsNothing);
      await t.pumpWidget(_host(const AQGlass(opaque: true, child: SizedBox(width: 100, height: 40))));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('small overlays skip the blur (blur 0) and keep the look', (t) async {
      _size(t, 390);
      await t.pumpWidget(_host(const AQGlass(blur: 0, child: SizedBox(width: 30, height: 30))));
      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('draws in dark, Arabic and at 200% text without overflow', (t) async {
      _size(t, 320);
      for (final cfg in [(true, false, 1.0), (false, true, 1.0), (true, true, 2.0)]) {
        await t.pumpWidget(_host(const AQGlass(padding: EdgeInsets.all(12), child: Text('Shop    Work')), dark: cfg.$1, rtl: cfg.$2, scale: cfg.$3));
        await t.pump();
        expect(t.takeException(), isNull, reason: '$cfg');
      }
    });
  });

  group('one media system', () {
    test('every kind has its own frame ratio', () {
      expect(AqMediaKind.avatar.ratio, 1);
      expect(AqMediaKind.logo.ratio, 1);
      expect(AqMediaKind.cover.ratio, closeTo(16 / 9, 1e-9));
      expect(AqMediaKind.portfolio.ratio, closeTo(4 / 3, 1e-9));
    });

    testWidgets('frames: avatar and logo are squares, a cover is wide', (t) async {
      _size(t, 390);
      final img = AqMediaImage(Uint8List.fromList(_png));
      await t.pumpWidget(_host(Column(children: [
        AqMediaFrame(kind: AqMediaKind.avatar, image: img, width: 120),
        AqMediaFrame(kind: AqMediaKind.cover, image: img, width: 320),
        AqMediaFrame(kind: AqMediaKind.logo, image: img, width: 120),
      ])));
      await t.pump();
      final sizes = [for (var i = 0; i < 3; i++) t.getSize(find.byType(AqMediaFrame).at(i))];
      expect(sizes[0], const Size(120, 120));
      expect(sizes[1].width / sizes[1].height, closeTo(16 / 9, 0.02));
      expect(sizes[2], const Size(120, 120));
    });

    for (final kind in AqMediaKind.values) {
      testWidgets('${kind.name}: add, edit and confirm use the same flow', (t) async {
        _size(t, 390);
        AqMediaImage? got;
        await t.pumpWidget(_host(StatefulBuilder(builder: (c, set) => AqMediaField(kind: kind, value: got, onChanged: (v) => set(() => got = v))), overrides: _pick(_png)));
        await _settle(t);
        await t.tap(find.text('Add photo'));
        await _settle(t);
        expect(find.text('Use this picture'), findsOneWidget);
        await t.tap(find.text('Use this picture'));
        await _settle(t);
        expect(got, isNotNull);
        expect(t.takeException(), isNull);
      });
    }

    testWidgets('cancel in the editor keeps the old value', (t) async {
      _size(t, 390);
      AqMediaImage? got;
      await t.pumpWidget(_host(StatefulBuilder(builder: (c, set) => AqMediaField(kind: AqMediaKind.avatar, value: got, onChanged: (v) => set(() => got = v))), overrides: _pick(_png)));
      await _settle(t);
      await t.tap(find.text('Add photo'));
      await _settle(t);
      await t.tap(find.text('Cancel'));
      await _settle(t);
      expect(got, isNull);
    });

    testWidgets('the editor reframes: zoom and rotate change the result', (t) async {
      _size(t, 390);
      AqMediaImage? got;
      await t.pumpWidget(_host(StatefulBuilder(builder: (c, set) => AqMediaField(kind: AqMediaKind.cover, value: got, onChanged: (v) => set(() => got = v))), overrides: _pick(_png)));
      await _settle(t);
      await t.tap(find.text('Add photo'));
      await _settle(t);
      await t.drag(find.byType(Slider), const Offset(120, 0));
      await t.tap(find.bySemanticsLabel('Rotate'));
      await _settle(t);
      await t.tap(find.text('Use this picture'));
      await _settle(t);
      expect(got!.zoom, greaterThan(1));
      expect(got!.turns, 1);
    });

    testWidgets('a PDF is refused before the editor opens', (t) async {
      _size(t, 390);
      await t.pumpWidget(_host(AqMediaField(kind: AqMediaKind.logo, value: null, onChanged: (_) {}), overrides: _pick(const [0x25, 0x50, 0x44, 0x46, 1, 2])));
      await _settle(t);
      await t.tap(find.text('Add photo'));
      await _settle(t);
      expect(find.text('Choose a JPG or PNG picture.'), findsOneWidget);
      expect(find.text('Use this picture'), findsNothing);
    });

    testWidgets('an existing picture offers Reposition and Remove in the same sheet', (t) async {
      _size(t, 390);
      AqMediaImage? got = AqMediaImage(Uint8List.fromList(_png));
      await t.pumpWidget(_host(StatefulBuilder(builder: (c, set) => AqMediaField(kind: AqMediaKind.avatar, value: got, onChanged: (v) => set(() => got = v)))));
      await _settle(t);
      await t.tap(find.text('Change photo'));
      await _settle(t);
      expect(find.text('Choose from this device'), findsOneWidget);
      expect(find.text('Reposition'), findsOneWidget);
      expect(find.text('Remove photo'), findsOneWidget);
      await t.tap(find.text('Remove photo'));
      await _settle(t);
      expect(got, isNull);
    });

    test('a picture from the device is registered once and reused like a bundled path', () {
      final img = AqMediaImage(Uint8List.fromList(_png));
      final a = registerAqMedia(img);
      expect(registerAqMedia(img), a);
      expect(aqMemoryMedia[a], img);
      expect(a, startsWith('memory:'));
    });

    testWidgets('the business logo shows only once one is set, in its own square frame', (t) async {
      _size(t, 390);
      await t.pumpWidget(_host(const AQBusinessLogo(size: 56, fallback: Text('none'))));
      expect(find.text('none'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(_host(const AQBusinessLogo(size: 56, fallback: Text('none')), overrides: [businessLogoProvider.overrideWith((ref) => AqMediaImage(Uint8List.fromList(_png)))]));
      await t.pump();
      expect(find.text('none'), findsNothing);
      expect(t.getSize(find.byType(AQBusinessLogo)), const Size(56, 56));
    });
  });
}
