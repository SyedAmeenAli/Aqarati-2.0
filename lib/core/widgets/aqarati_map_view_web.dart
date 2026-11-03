import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViewTypes = {};
final Map<String, VoidCallback?> _loadCallbacks = {};
final Map<String, VoidCallback?> _errorCallbacks = {};

/// Real Google Maps on Flutter Web via the classic keyless embed
/// (`maps.google.com/maps?...&output=embed`) — the same no-API-key
/// mechanism as Google's own "Share > Embed a map" iframe, generalized to
/// take any lat/lng so every property gets a real, live map, not a fixed
/// one-location embed.
Widget buildWebEmbedMap({
  required double lat,
  required double lng,
  required double zoom,
  bool interactive = true,
  int attempt = 0,
  VoidCallback? onLoaded,
  VoidCallback? onError,
}) {
  final src =
      'https://maps.google.com/maps?q=$lat,$lng&z=${zoom.round()}&output=embed';
  final viewType = 'aqarati-map-$lat-$lng-${zoom.round()}-$interactive-$attempt';
  _loadCallbacks[viewType] = onLoaded;
  _errorCallbacks[viewType] = onError;

  // registerViewFactory throws if called twice for the same viewType, and
  // this widget rebuilds often (camera moves, state changes) — register once.
  if (_registeredViewTypes.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = src
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        // The app creates this frame only once the map is visible or opened, so the browser loads it at once.
        ..loading = 'eager'
        ..referrerPolicy = 'no-referrer-when-downgrade';
      // The frame is only called loaded once the browser says so; until then the app shows a skeleton.
      iframe.addEventListener('load', ((web.Event _) => _loadCallbacks[viewType]?.call()).toJS);
      iframe.addEventListener('error', ((web.Event _) => _errorCallbacks[viewType]?.call()).toJS);
      // Flutter's IgnorePointer only affects Flutter's own hit-test tree —
      // a platform-view iframe still receives real DOM pointer events
      // directly, so a non-interactive preview (e.g. Home's compact card)
      // must disable pointer events on the iframe element itself, or taps
      // open Google's own UI instead of the card's onTap.
      if (!interactive) {
        iframe.style.pointerEvents = 'none';
      }
      return iframe;
    });
  }

  return HtmlElementView(viewType: viewType);
}
