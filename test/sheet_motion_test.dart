import 'package:aqarati_app/core/aq/aq_scene.dart';
import 'package:aqarati_app/core/aq/aq_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The bottom sheet used by Filters, sort and the guest gate really slides: its top edge is sampled frame
/// by frame, so this does not depend on how often a browser screencast happens to capture frames.
void main() {
  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showAQSheet<void>(context, builder: (_) => const SizedBox(height: 360, child: Center(child: Text('SHEET BODY')))),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
  }

  testWidgets('the sheet rises through intermediate positions and settles', (t) async {
    await open(t);
    final samples = <double>[];
    final steps = AQMotion.sheet.inMilliseconds ~/ 20;
    for (var i = 0; i <= steps + 2; i++) {
      await t.pump(i == 0 ? Duration.zero : const Duration(milliseconds: 20));
      final f = find.text('SHEET BODY');
      samples.add(f.evaluate().isEmpty ? double.infinity : t.getTopLeft(f).dy);
    }
    final visible = samples.where((y) => y.isFinite).toList();
    expect(visible.length, greaterThan(5), reason: 'sampled across the whole transition: $samples');
    for (var i = 1; i < visible.length; i++) {
      expect(visible[i], lessThanOrEqualTo(visible[i - 1] + 0.01), reason: 'never moves back down while opening: $visible');
    }
    final first = visible.first, last = visible.last;
    expect(first - last, greaterThan(250), reason: 'it travels most of its own height: $visible');
    final between = visible.where((y) => y < first - 20 && y > last + 20).length;
    expect(between, greaterThanOrEqualTo(4), reason: 'several distinct in-between positions: $visible');
    await t.pump(const Duration(seconds: 1));
    expect(t.getTopLeft(find.text('SHEET BODY')).dy, closeTo(last, 0.5), reason: 'settled where the last sample ended');
  });
}
