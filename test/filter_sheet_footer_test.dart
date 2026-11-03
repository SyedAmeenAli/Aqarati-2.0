import 'package:aqarati_app/data/datasources/mock_property_data.dart';
import 'package:aqarati_app/features/search/aq_filter_sheet.dart';
import 'package:aqarati_app/features/search/aq_filters.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// the screen.
void main() {
  for (final w in [320.0, 343.0, 390.0]) {
    testWidgets('filter sheet footer at ${w.toInt()} px: side by side and on screen', (t) async {
      t.view.physicalSize = Size(w, 706);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAQFilterSheet(context, all: mockProperties, initial: AQFilters()),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.text('open'));
      for (var i = 0; i < 10; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      final reset = find.text('Reset');
      final show = find.textContaining(RegExp(r'^Show \d+ results$'));
      expect(reset, findsOneWidget);
      expect(show, findsOneWidget);
      final rr = t.getRect(reset), sr = t.getRect(show);
      // The one-line label check needs the real fonts, so it lives in the browser run (j100_filters); here the default
      // test font is wider than the app font. This test covers geometry only.
      expect(sr.left, greaterThanOrEqualTo(0));
      expect(sr.right, lessThanOrEqualTo(w));
      expect(sr.bottom, lessThanOrEqualTo(706));
      expect(rr.bottom, lessThanOrEqualTo(706));
      expect(rr.right, lessThan(sr.left), reason: 'side by side, not overlapping');
    });
  }
}
