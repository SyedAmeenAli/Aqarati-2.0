import 'package:aqarati_app/core/widgets/map_embed_lifecycle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The embedded map's lifecycle: idle until activated, the 12-second timeout only after activation,
/// the load event as "document loaded" only, failure, retry, and leaving while loading.
void main() {
  group('MapEmbedLifecycle', () {
    testWidgets('stays idle and never starts a timer before activation', (t) async {
      final life = MapEmbedLifecycle();
      var notified = 0;
      life.addListener(() => notified++);
      await t.pump(const Duration(seconds: 60));
      expect(life.phase, MapEmbedPhase.idle);
      expect(notified, 0);
      // testWidgets fails the test if a timer is still pending at the end, so a stray timeout would show here.
      life.dispose();
    });

    testWidgets('activation starts loading; the timeout runs from then, not before', (t) async {
      final life = MapEmbedLifecycle();
      await t.pump(const Duration(seconds: 30)); // time spent idle does not count
      life.activate();
      expect(life.phase, MapEmbedPhase.loading);
      await t.pump(const Duration(milliseconds: 11900));
      expect(life.phase, MapEmbedPhase.loading);
      await t.pump(const Duration(milliseconds: 200));
      expect(life.phase, MapEmbedPhase.failed);
      life.dispose();
    });

    testWidgets('the frame load event moves to loaded and cancels the timeout', (t) async {
      final life = MapEmbedLifecycle();
      life.activate();
      await t.pump(const Duration(seconds: 3));
      life.onLoaded(life.attempt);
      expect(life.phase, MapEmbedPhase.loaded);
      await t.pump(const Duration(seconds: 30));
      expect(life.phase, MapEmbedPhase.loaded, reason: 'a loaded map is never failed later by the old timeout');
      life.dispose();
    });

    testWidgets('a load error fails at once', (t) async {
      final life = MapEmbedLifecycle();
      life.activate();
      life.onError(life.attempt);
      expect(life.phase, MapEmbedPhase.failed);
      await t.pump(const Duration(seconds: 30));
      expect(life.phase, MapEmbedPhase.failed);
      life.dispose();
    });

    testWidgets('retry starts a new attempt with a full timeout, and ignores the old attempt', (t) async {
      final life = MapEmbedLifecycle();
      life.activate();
      await t.pump(const Duration(seconds: 13));
      expect(life.phase, MapEmbedPhase.failed);
      final first = life.attempt;
      life.retry();
      expect(life.phase, MapEmbedPhase.loading);
      expect(life.attempt, first + 1);
      life.onLoaded(first); // a late event from the first attempt
      expect(life.phase, MapEmbedPhase.loading);
      await t.pump(const Duration(seconds: 11));
      expect(life.phase, MapEmbedPhase.loading, reason: 'the second attempt has its own 12 s');
      await t.pump(const Duration(seconds: 2));
      expect(life.phase, MapEmbedPhase.failed);
      life.retry();
      life.onLoaded(life.attempt);
      expect(life.phase, MapEmbedPhase.loaded);
      life.dispose();
    });

    testWidgets('retry only works from the failed state', (t) async {
      final life = MapEmbedLifecycle();
      life.retry();
      expect(life.phase, MapEmbedPhase.idle);
      life.activate();
      life.retry();
      expect(life.attempt, 0);
      life.dispose();
    });

    testWidgets('leaving while loading cancels the timeout and ignores late events', (t) async {
      final life = MapEmbedLifecycle();
      life.activate();
      await t.pump(const Duration(seconds: 2));
      life.dispose(); // the screen was left
      await t.pump(const Duration(seconds: 30)); // would throw "a Timer is still pending" if not cancelled
      life.onLoaded(0);
      life.onError(0);
    });

    testWidgets('with no timeout the loading state is held', (t) async {
      final life = MapEmbedLifecycle(timeout: null);
      life.activate();
      await t.pump(const Duration(seconds: 120));
      expect(life.phase, MapEmbedPhase.loading);
      life.dispose();
    });
  });

  group('VisibilityGate', () {
    Widget page(ScrollController c, VoidCallback onVisible, {bool ticking = true}) => MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: ticking,
              child: ListView(controller: c, children: [
                const SizedBox(height: 2400),
                VisibilityGate(onVisible: onVisible, child: const SizedBox(height: 200, child: Text('map'))),
                const SizedBox(height: 800),
              ]),
            ),
          ),
        );

    testWidgets('a map far below the fold does not activate until it is scrolled near', (t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      final c = ScrollController();
      var fired = 0;
      await t.pumpWidget(page(c, () => fired++));
      await t.pump(const Duration(seconds: 20));
      expect(fired, 0);
      c.jumpTo(1000);
      await t.pump();
      await t.pump();
      expect(fired, 0, reason: 'still below the screen');
      c.jumpTo(1800);
      await t.pump();
      await t.pump();
      expect(fired, 1);
      c.jumpTo(1500); // out of view again, but still built (a lazily built list would recreate it)
      await t.pump();
      c.jumpTo(1800);
      await t.pump();
      await t.pump();
      expect(fired, 1, reason: 'it fires once');
    });

    testWidgets('a map already on screen activates on the first frame', (t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var fired = 0;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: VisibilityGate(onVisible: () => fired++, child: const SizedBox(height: 300)))));
      await t.pump();
      expect(fired, 1);
    });

    testWidgets('an off-stage subtree never activates', (t) async {
      t.view.physicalSize = const Size(400, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      var fired = 0;
      await t.pumpWidget(MaterialApp(home: Scaffold(body: TickerMode(enabled: false, child: VisibilityGate(onVisible: () => fired++, child: const SizedBox(height: 300))))));
      await t.pump();
      await t.pump(const Duration(seconds: 5));
      expect(fired, 0);
    });
  });
}
