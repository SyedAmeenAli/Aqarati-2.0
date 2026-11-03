import 'package:flutter/material.dart';

/// Non-web platforms have no iframe embed — native Android/iOS keep using
/// the real `GoogleMap` widget (gated by `kGoogleMapsConfigured`) instead.
Widget buildWebEmbedMap({
  required double lat,
  required double lng,
  required double zoom,
  bool interactive = true,
  int attempt = 0,
  VoidCallback? onLoaded,
  VoidCallback? onError,
}) {
  throw UnsupportedError(
    'Web embed map is web-only; native platforms use GoogleMap directly.',
  );
}
