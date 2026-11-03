import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Where an embedded live map is in its life. [idle] means nothing has been requested from the map
/// service yet and no timer is running.
enum MapEmbedPhase { idle, loading, loaded, failed }

/// The loading lifecycle of an embedded map frame, kept free of any browser code so it can be tested.
///
/// - Nothing happens until [activate]: no request, no timeout.
/// - [activate] starts the loading phase and, if a [timeout] is set, the timeout.
/// - The frame's `load` event ([onLoaded]) means the embedded document arrived. It is not evidence that map
///   tiles have painted, and this class does not claim it is.
/// - A load error or the timeout moves to [MapEmbedPhase.failed]; [retry] starts a fresh attempt with a fresh
///   timeout. Events from an earlier attempt are ignored.
class MapEmbedLifecycle extends ChangeNotifier {
  /// `null` never times out (review builds hold the loading state with it).
  final Duration? timeout;
  MapEmbedLifecycle({this.timeout = const Duration(seconds: 12)});

  MapEmbedPhase _phase = MapEmbedPhase.idle;
  int _attempt = 0;
  Timer? _timer;
  bool _disposed = false;

  MapEmbedPhase get phase => _phase;

  /// Increments on every retry; the web frame uses it to create a new iframe.
  int get attempt => _attempt;

  void activate() {
    if (_disposed || _phase != MapEmbedPhase.idle) return;
    _begin();
  }

  void _begin() {
    _phase = MapEmbedPhase.loading;
    _timer?.cancel();
    final t = timeout;
    if (t != null) {
      final started = _attempt;
      _timer = Timer(t, () {
        if (!_disposed && _attempt == started && _phase == MapEmbedPhase.loading) _set(MapEmbedPhase.failed);
      });
    }
    notifyListeners();
  }

  void _set(MapEmbedPhase p) {
    _timer?.cancel();
    _timer = null;
    _phase = p;
    notifyListeners();
  }

  /// The frame reported `load` for [forAttempt].
  void onLoaded(int forAttempt) {
    if (_disposed || forAttempt != _attempt || _phase != MapEmbedPhase.loading) return;
    _set(MapEmbedPhase.loaded);
  }

  /// The frame reported an error for [forAttempt].
  void onError(int forAttempt) {
    if (_disposed || forAttempt != _attempt || _phase != MapEmbedPhase.loading) return;
    _set(MapEmbedPhase.failed);
  }

  /// Review builds only: show the failure state without a request.
  void forceFailed() {
    if (_disposed) return;
    _set(MapEmbedPhase.failed);
  }

  void retry() {
    if (_disposed || _phase != MapEmbedPhase.failed) return;
    _attempt++;
    _begin();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// Calls [onVisible] once, the first time any part of [child] is within the screen and its subtree is
/// active (not an off-stage tab or a covered route). It watches the nearest scrollable, so a map far down a
/// page stays idle until it is scrolled near. Nothing is polled.
class VisibilityGate extends StatefulWidget {
  final Widget child;
  final VoidCallback onVisible;

  /// How many logical pixels of the child must be inside the screen.
  final double minVisible;
  const VisibilityGate({super.key, required this.child, required this.onVisible, this.minVisible = 24});

  @override
  State<VisibilityGate> createState() => _VisibilityGateState();
}

class _VisibilityGateState extends State<VisibilityGate> {
  ScrollPosition? _position;
  bool _fired = false;
  bool _scheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    TickerMode.of(context); // re-check when the subtree becomes active (a tab or route coming forward)
    final next = Scrollable.maybeOf(context)?.position;
    if (!identical(next, _position)) {
      _position?.removeListener(_schedule);
      _position = next;
      _position?.addListener(_schedule);
    }
    _schedule();
  }

  void _schedule() {
    if (_fired || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) _check();
    });
  }

  void _check() {
    if (_fired) return;
    if (!TickerMode.of(context)) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final bottom = top + box.size.height;
    final screen = View.of(context).physicalSize.height / View.of(context).devicePixelRatio;
    final visible = bottom.clamp(0.0, screen) - top.clamp(0.0, screen);
    if (visible >= widget.minVisible.clamp(0.0, box.size.height)) {
      _fired = true;
      widget.onVisible();
    }
  }

  @override
  void dispose() {
    _position?.removeListener(_schedule);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A rebuild (for example a section opening above) can move the child on screen without a scroll.
    _schedule();
    return widget.child;
  }
}
