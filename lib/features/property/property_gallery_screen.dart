import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/property.dart';
import '../viewing/widgets/viewing_format.dart';

// A photograph viewer sits on a deep warm dark in both themes so the pictures lead.
const _stage = Color(0xFF14110F);
const _onStage = Color(0xFFF7F2EA);
const _onStageSoft = Color(0xB3F7F2EA);
const _priceTan = Color(0xFFE2BC97);

enum _Kind { photos, video }

/// Photos and video for one listing: swipe between photos, pinch to zoom, real counts, and an honest
/// empty state when the listing has no media.
class PropertyGalleryScreen extends StatefulWidget {
  final Property property;
  const PropertyGalleryScreen({super.key, required this.property});

  @override
  State<PropertyGalleryScreen> createState() => _PropertyGalleryScreenState();
}

class _PropertyGalleryScreenState extends State<PropertyGalleryScreen> {
  _Kind _kind = _Kind.photos;
  int _index = 0;
  final _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _kindPill(BuildContext context, String label, _Kind k) {
    final on = _kind == k;
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: on,
      label: label,
      excludeSemantics: true,
      onTap: () => setState(() {
          _kind = k;
          _index = 0;
        }),
      child: AQPressable(
        onTap: () => setState(() {
          _kind = k;
          _index = 0;
        }),
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          constraints: const BoxConstraints(
            minHeight: AQControl.tap - 4,
            minWidth: 72,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? c.accent : const Color(0x22F7F2EA),
            borderRadius: BorderRadius.circular(AQRadius.large),
          ),
          child: Text(
            label,
            style: AQTypography.of(
              context,
              AQText.labelLarge,
              color: on ? c.onAccent : _onStage,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final p = widget.property;
    final images = p.imageUrls;
    final videos = p.videoUrls;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _stage,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_kind == _Kind.video)
                      _VideoStage(videoUrls: videos)
                    else if (images.isEmpty)
                      _Message(f.t('gal.none'))
                    else
                      PageView.builder(
                        controller: _pages,
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => Semantics(
                          label:
                              '${f.t('gal.photos')} ${f.t('gal.count', {'a': VFmt.n(context, i + 1), 'b': VFmt.n(context, images.length)})}',
                          image: true,
                          child: InteractiveViewer(
                            minScale: 1,
                            maxScale: 4,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AQSpacing.x2,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AQRadius.medium,
                                ),
                                child: Image.asset(
                                  images[i],
                                  fit: BoxFit.contain,
                                  frameBuilder: (context, child, frame, sync) => sync || AQMotion.reduced(context)
                                      ? child
                                      : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: AQMotion.scaled(context, AQMotion.slow), curve: Curves.easeOut, child: child),
                                  errorBuilder: (context, _, _) =>
                                      _Message(f.t('gal.err')),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    PositionedDirectional(
                      start: AQSpacing.x2,
                      top: AQSpacing.x2,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: Color(0x66000000),
                          shape: BoxShape.circle,
                        ),
                        child: AQIconButton(
                          icon: 'chevron-left',
                          semanticsLabel: f.t('common.back'),
                          color: _onStage,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    if (_kind == _Kind.photos && images.isNotEmpty)
                      Positioned(
                        bottom: AQSpacing.x3,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Semantics(
                            liveRegion: true,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: const Color(0x99000000),
                                borderRadius: BorderRadius.circular(
                                  AQRadius.large,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AQSpacing.x4,
                                  vertical: 6,
                                ),
                                child: Text(
                                  f.t('gal.count', {
                                    'a': VFmt.n(context, _index + 1),
                                    'b': VFmt.n(context, images.length),
                                  }),
                                  style: AQTypography.of(
                                    context,
                                    AQText.labelMedium,
                                    color: _onStage,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AQSpacing.gutter,
                  AQSpacing.x4,
                  AQSpacing.gutter,
                  0,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            VFmt.iso(p.title),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AQTypography.of(
                              context,
                              AQText.titleMedium,
                              color: _onStage,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            VFmt.iso(
                              p.locationLabel
                                  .split(',')
                                  .take(2)
                                  .join(',')
                                  .trim(),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              color: _onStageSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AQSpacing.x3),
                    Text(
                      p.price.compact,
                      style: AQTypography.of(
                        context,
                        AQText.titleMedium,
                        color: _priceTan,
                      ),
                    ),
                  ],
                ),
              ),
              if (videos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AQSpacing.gutter,
                    AQSpacing.x3,
                    AQSpacing.gutter,
                    0,
                  ),
                  child: Row(
                    children: [
                      _kindPill(context, f.t('gal.photos'), _Kind.photos),
                      const SizedBox(width: AQSpacing.x2),
                      _kindPill(context, f.t('gal.video'), _Kind.video),
                    ],
                  ),
                ),
              const SizedBox(height: AQSpacing.x4),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final String text;
  const _Message(this.text);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AQSpacing.x6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: AQTypography.of(context, AQText.bodyMedium, color: _onStageSoft),
      ),
    ),
  );
}

class _VideoStage extends StatefulWidget {
  final List<String> videoUrls;
  const _VideoStage({required this.videoUrls});
  @override
  State<_VideoStage> createState() => _VideoStageState();
}

class _VideoStageState extends State<_VideoStage> {
  VideoPlayerController? _controller;
  int _index = 0;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(0);
  }

  void _load(int i) {
    _controller?.dispose();
    _failed = false;
    if (widget.videoUrls.isEmpty) return;
    final c = VideoPlayerController.asset(widget.videoUrls[i]);
    _controller = c;
    c
        .initialize()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((_) {
          if (mounted) setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    if (widget.videoUrls.isEmpty) return _Message(f.t('gal.novideo'));
    if (_failed) return _Message(f.t('gal.err'));
    final v = _controller;
    final ready = v != null && v.value.isInitialized;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: ready
                ? Semantics(
                    button: true,
                    focusable: true,
                    onFocus: () {},
                    label: v.value.isPlaying
                        ? f.t('gal.pause')
                        : f.t('gal.play'),
                    excludeSemantics: true,
      onTap: () => setState(
                        () => v.value.isPlaying ? v.pause() : v.play(),
                      ),
                    child: AQPressable(
                      onTap: () => setState(
                        () => v.value.isPlaying ? v.pause() : v.play(),
                      ),
                      child: AspectRatio(
                        aspectRatio: v.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AQRadius.medium,
                              ),
                              child: VideoPlayer(v),
                            ),
                            if (!v.value.isPlaying)
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: Color(0x99000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.all(AQSpacing.x3),
                                  child: Icon(
                                    Icons.play_arrow_rounded,
                                    size: 44,
                                    color: _onStage,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  )
                : SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: c.accent,
                    ),
                  ),
          ),
        ),
        if (widget.videoUrls.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3),
            child: Wrap(
              spacing: AQSpacing.x2,
              children: [
                for (var i = 0; i < widget.videoUrls.length; i++)
                  Semantics(
                    button: true,
                    focusable: true,
                    onFocus: () {},
                    selected: i == _index,
                    label: f.t('gal.videoN', {'n': VFmt.n(context, i + 1)}),
                    excludeSemantics: true,
      onTap: () => setState(() {
                        _index = i;
                        _load(i);
                      }),
                    child: AQPressable(
                      onTap: () => setState(() {
                        _index = i;
                        _load(i);
                      }),
                      child: Container(
                        width: AQControl.tap,
                        height: AQControl.tap - 4,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: i == _index
                              ? c.accent
                              : const Color(0x22F7F2EA),
                          borderRadius: BorderRadius.circular(AQRadius.small),
                        ),
                        child: Text(
                          VFmt.n(context, i + 1),
                          style: AQTypography.of(
                            context,
                            AQText.labelLarge,
                            color: i == _index ? c.onAccent : _onStage,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
