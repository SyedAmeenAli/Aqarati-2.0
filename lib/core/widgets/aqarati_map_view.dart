import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../config/backend_mode.dart';
import '../config/maps_config.dart';
import '../localization/flow_strings.dart';
import 'map_embed_lifecycle.dart';
import '../aq/aq_tokens.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import 'aqarati_map_view_stub.dart'
    if (dart.library.js_interop) 'aqarati_map_view_web.dart'
    as web_map;

/// Single reusable Google Map surface for the whole app (Home "Near you"
/// preview, full Map screen, and any future property-detail map). Callers
/// supply markers/camera; this widget owns only the map itself.
///
/// Web renders a real, live Google Map via the classic keyless
/// `output=embed` iframe (no API key/billing needed, same mechanism as
/// Google's own "Share > Embed a map"). Native Android/iOS render the real
/// `GoogleMap` widget when [kGoogleMapsConfigured] is set for a real key, or
/// a clean unavailable state otherwise — never a painted/fake map.
class AqaratiMapView extends StatefulWidget {
  final LatLng initialCenter;
  final double initialZoom;
  final Set<Marker> markers;
  final bool interactive;
  final BorderRadius? borderRadius;
  final ValueChanged<GoogleMapController>? onMapCreated;
  final VoidCallback? onCameraMove;
  final VoidCallback? onCameraIdle;
  /// Parts of the map box that the host screen covers with its own controls. The loading and failure
  /// messages, and the live-map chip, sit in the uncovered part so they are never hidden.
  final EdgeInsets overlayInsets;

  const AqaratiMapView({
    super.key,
    required this.initialCenter,
    this.initialZoom = 12,
    this.markers = const {},
    this.interactive = true,
    this.borderRadius,
    this.onMapCreated,
    this.onCameraMove,
    this.onCameraIdle,
    this.overlayInsets = EdgeInsets.zero,
  });

  @override
  State<AqaratiMapView> createState() => _AqaratiMapViewState();
}

class _AqaratiMapViewState extends State<AqaratiMapView> {
  GoogleMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(AppRadius.md);

    if (kIsWeb) {
      return ClipRRect(
        borderRadius: radius,
        child: _WebMapFrame(
          lat: widget.initialCenter.latitude,
          lng: widget.initialCenter.longitude,
          zoom: widget.initialZoom,
          interactive: widget.interactive,
          overlayInsets: widget.overlayInsets,
        ),
      );
    }

    if (!kGoogleMapsConfigured) {
      return ClipRRect(
        borderRadius: radius,
        child: const _MapUnavailableView(),
      );
    }

    return ClipRRect(
      borderRadius: radius,
      child: GoogleMap(
        initialCameraPosition: CameraPosition(
          target: widget.initialCenter,
          zoom: widget.initialZoom,
        ),
        markers: widget.markers,
        onMapCreated: (controller) {
          _controller = controller;
          widget.onMapCreated?.call(controller);
        },
        onCameraMove: (_) => widget.onCameraMove?.call(),
        onCameraIdle: widget.onCameraIdle,
        myLocationButtonEnabled: false,
        zoomControlsEnabled: false,
        rotateGesturesEnabled: widget.interactive,
        scrollGesturesEnabled: widget.interactive,
        tiltGesturesEnabled: widget.interactive,
        zoomGesturesEnabled: widget.interactive,
        liteModeEnabled: !widget.interactive,
      ),
    );
  }

  Future<void> animateTo(LatLng target, {double zoom = 14}) async {
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}

/// Shown wherever a map surface would render but no Google Maps API key is
/// configured for this platform/build — never a painted/fake map standing
/// in for live data.
class _MapUnavailableView extends StatelessWidget {
  const _MapUnavailableView();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sand,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.map_outlined, color: AppColors.mist, size: 28),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Map unavailable',
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: AppColors.charcoal),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            'Google Maps configuration is required for this environment.',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: AppColors.mist),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


/// The live web map. It stays idle, with no request and no timer, until it is scrolled into view or
/// the person taps "Show map". Only then is the frame created and the timeout started. While loading a
/// skeleton shows; a load error or the timeout shows a retry state. The frame's `load` event means its
/// document arrived, not that tiles have painted. A small chip says the map is a live service while any
/// listing positions are sample data in this preview.
class _WebMapFrame extends StatefulWidget {
  final double lat, lng, zoom;
  final bool interactive;
  final EdgeInsets overlayInsets;
  const _WebMapFrame({required this.lat, required this.lng, required this.zoom, required this.interactive, required this.overlayInsets});
  @override
  State<_WebMapFrame> createState() => _WebMapFrameState();
}

class _WebMapFrameState extends State<_WebMapFrame> with SingleTickerProviderStateMixin {
  /// Review builds only: `?map=loading` holds the loading state and `?map=fail` shows the failure state, so both
  /// can be inspected without slowing the real map down. `?map=idle` keeps the map idle.
  static final String? _force = kShowReviewTools && kIsWeb ? Uri.base.queryParameters['map'] : null;

  late final MapEmbedLifecycle _life = MapEmbedLifecycle(timeout: _force == null ? const Duration(seconds: 12) : null);
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    // Forced states are set up before listening, so nothing rebuilds during initState.
    if (_force == 'loading') _life.activate();
    if (_force == 'fail') {
      _life.activate();
      _life.forceFailed();
    }
    _life.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// [explicit] is the person tapping "Show map"; the review-only idle hold ignores only the automatic trigger.
  void _activate({bool explicit = false}) {
    if (_force == 'idle' && !explicit) return;
    _life.activate();
  }

  void _retry() {
    if (_force == 'fail') return;
    _life.retry();
  }

  @override
  void dispose() {
    _life.removeListener(_changed);
    _life.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final still = MediaQuery.of(context).disableAnimations;
    final phase = _life.phase;
    final loading = phase == MapEmbedPhase.loading;
    if (loading && !still && !_pulse.isAnimating) _pulse.repeat(reverse: true);
    if (!loading && _pulse.isAnimating) _pulse.stop();
    return VisibilityGate(
      onVisible: _activate,
      child: LayoutBuilder(builder: (context, box) {
        final small = box.maxHeight < 150 || box.maxWidth < 220;
        // Never let the host's covered areas squeeze the message out of a short map box.
        final ins = EdgeInsets.fromLTRB(widget.overlayInsets.left, widget.overlayInsets.top.clamp(0.0, box.maxHeight * 0.3), widget.overlayInsets.right, widget.overlayInsets.bottom.clamp(0.0, box.maxHeight * 0.5));
        final Widget overlay;
        switch (phase) {
          case MapEmbedPhase.idle:
            overlay = _MapStatus(key: const ValueKey('idle'), inset: ins, icon: Icons.map_outlined, title: f.t('map.idle.t'), body: small ? null : f.t('map.idle.b'), action: f.t('map.show'), onAction: () => _activate(explicit: true), small: small);
          case MapEmbedPhase.loading:
            overlay = AnimatedBuilder(
              key: const ValueKey('loading'),
              animation: _pulse,
              builder: (context, _) => _MapStatus(inset: ins, icon: Icons.map_outlined, title: f.t('map.loading'), small: small, pulse: still ? 0.5 : _pulse.value),
            );
          case MapEmbedPhase.failed:
            overlay = _MapStatus(key: const ValueKey('failed'), inset: ins, icon: Icons.cloud_off_outlined, title: f.t('map.failed.t'), body: small ? null : f.t('map.failed.b'), action: f.t('map.retry'), onAction: _retry, small: small);
          case MapEmbedPhase.loaded:
            overlay = const SizedBox.expand(key: ValueKey('ready'));
        }
        return Stack(fit: StackFit.expand, children: [
          // The frame exists only while a request is intended: loading or loaded.
          if (phase == MapEmbedPhase.loading || phase == MapEmbedPhase.loaded)
            web_map.buildWebEmbedMap(
              lat: widget.lat,
              lng: widget.lng,
              zoom: widget.zoom,
              interactive: widget.interactive,
              attempt: _life.attempt,
              onLoaded: _force == null ? () => _life.onLoaded(_life.attempt) : null,
              onError: _force == null ? () => _life.onError(_life.attempt) : null,
            ),
          IgnorePointer(
            ignoring: phase == MapEmbedPhase.loaded,
            child: AnimatedSwitcher(duration: still ? Duration.zero : const Duration(milliseconds: 260), child: overlay),
          ),
          if (phase == MapEmbedPhase.loaded && !small)
            PositionedDirectional(
              start: 8 + ins.left,
              bottom: 20 + ins.bottom,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xCC2D2823), borderRadius: BorderRadius.circular(10)),
                  child: Text(kUseDemoBackend ? f.t('map.chip.demo') : f.t('map.chip.live'), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white)),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

class _MapStatus extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? body;
  final String? action;
  final VoidCallback? onAction;
  final bool small;
  final double? pulse;
  final EdgeInsets inset;
  const _MapStatus({super.key, this.inset = EdgeInsets.zero, required this.icon, required this.title, this.body, this.action, this.onAction, this.small = false, this.pulse});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // Light theme keeps the sand panel; dark theme uses the dark surface and tokens so the text and the retry
    // action keep their contrast.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = AQColors.of(context);
    final titleColor = dark ? c.ink : AppColors.charcoal;
    final mutedColor = dark ? c.inkSoft : AppColors.mist;
    return Container(
      color: dark ? Color.lerp(c.surfaceRaised, c.surfaceSelected, pulse ?? 0) : Color.lerp(const Color(0xFFEDE3D3), Colors.white, (pulse ?? 0) * 0.35),
      alignment: Alignment.center,
      padding: inset + EdgeInsets.all(small ? AppSpacing.xs : AppSpacing.md),
      child: FittedBox(fit: BoxFit.scaleDown, child: SizedBox(width: 260, child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: mutedColor, size: small ? 22 : 30),
        SizedBox(height: small ? 2 : AppSpacing.xs),
        Text(title, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: titleColor)),
        if (body != null) ...[
          const SizedBox(height: 2),
          Text(body!, textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: mutedColor)),
        ],
        if (action != null) ...[
          SizedBox(height: small ? 4 : AppSpacing.sm),
          TextButton(style: dark ? TextButton.styleFrom(foregroundColor: c.accentDeep) : null, onPressed: onAction, child: Text(action!)),
        ],
      ]))),
    );
  }
}
