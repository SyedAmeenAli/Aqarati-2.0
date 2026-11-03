import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../flow/state/document_state.dart' show documentPickerProvider, hasAllowedSignature;

/// One media system for the whole app. A personal photo, a company logo, a cover picture and a portfolio
/// picture all go through the same sheet, the same preview and crop editor and the same confirm step; only
/// the frame differs (a person is a circle, a logo is a contained square, a cover is wide).
enum AqMediaKind { avatar, logo, cover, portfolio }

extension AqMediaKindX on AqMediaKind {
  /// Width over height of the frame.
  double get ratio => switch (this) {
    AqMediaKind.avatar || AqMediaKind.logo => 1,
    AqMediaKind.cover => 16 / 9,
    AqMediaKind.portfolio => 4 / 3,
  };
  String get titleKey => switch (this) {
    AqMediaKind.avatar => 'media.avatar',
    AqMediaKind.logo => 'media.logo',
    AqMediaKind.cover => 'media.cover',
    AqMediaKind.portfolio => 'media.portfolio',
  };
}

/// A chosen picture and how it is framed. Kept in the running app in this preview: nothing is uploaded.
@immutable
class AqMediaImage {
  final Uint8List bytes;

  /// 1 shows the whole frame filled; larger values zoom in.
  final double zoom;

  /// Where the picture sits in its frame, -1 to 1 on each axis.
  final double dx, dy;

  /// Quarter turns clockwise.
  final int turns;
  const AqMediaImage(this.bytes, {this.zoom = 1, this.dx = 0, this.dy = 0, this.turns = 0});

  AqMediaImage copyWith({double? zoom, double? dx, double? dy, int? turns}) =>
      AqMediaImage(bytes, zoom: zoom ?? this.zoom, dx: dx ?? this.dx, dy: dy ?? this.dy, turns: turns ?? this.turns);

  @override
  bool operator ==(Object o) => o is AqMediaImage && identical(o.bytes, bytes) && o.zoom == zoom && o.dx == dx && o.dy == dy && o.turns == turns;
  @override
  int get hashCode => Object.hash(identityHashCode(bytes), zoom, dx, dy, turns);
}

/// The person's own photograph. One image, shown everywhere the same person appears.
typedef ProfilePhoto = AqMediaImage;
final profilePhotoProvider = StateProvider<AqMediaImage?>((ref) => null);

/// The business: one logo and one cover, shown wherever the business appears.
final businessLogoProvider = StateProvider<AqMediaImage?>((ref) => null);
final businessCoverProvider = StateProvider<AqMediaImage?>((ref) => null);

/// Draws a picture in the frame of its [kind]. The same widget is used by the avatar, the logo frame, the
/// cover and the editor preview, so a picture can never look different on two screens.
class AqMediaView extends StatelessWidget {
  final AqMediaImage image;
  final AqMediaKind kind;
  const AqMediaView({super.key, required this.image, required this.kind});

  @override
  Widget build(BuildContext context) {
    final contain = kind == AqMediaKind.logo;
    return ExcludeSemantics(
      child: ClipRect(
        child: RotatedBox(
          quarterTurns: image.turns,
          child: Transform.scale(
            scale: image.zoom,
            child: Padding(
              padding: EdgeInsets.all(contain ? 10 : 0),
              child: Image.memory(
                image.bytes,
                fit: contain ? BoxFit.contain : BoxFit.cover,
                alignment: Alignment(image.dx, image.dy),
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A circular picture of the signed-in person, or a plain person icon when no photo has been added.
class AQAvatar extends ConsumerWidget {
  final double size;
  const AQAvatar({super.key, this.size = 44});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final photo = ref.watch(profilePhotoProvider);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle, border: Border.all(color: c.hairline)),
      child: ClipOval(child: photo == null ? Center(child: AQIcon('user', size: size * 0.5, color: c.accentDeep)) : AqMediaView(image: photo, kind: AqMediaKind.avatar)),
    );
  }
}

/// The business logo in a contained square frame, or the AQARATI-neutral placeholder when none is set.
class AQBusinessLogo extends ConsumerWidget {
  final double size;
  final Widget? fallback;
  const AQBusinessLogo({super.key, this.size = 56, this.fallback});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logo = ref.watch(businessLogoProvider);
    final c = AQColors.of(context);
    if (logo == null) return fallback ?? SizedBox(width: size, height: size);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(size * 0.22), border: Border.all(color: c.hairline)),
      child: ClipRRect(borderRadius: BorderRadius.circular(size * 0.22), child: AqMediaView(image: logo, kind: AqMediaKind.logo)),
    );
  }
}

/// The frame for a kind, with the picture in it (or an empty frame), at [width].
class AqMediaFrame extends StatelessWidget {
  final AqMediaKind kind;
  final AqMediaImage? image;
  final double width;
  final Widget? empty;
  const AqMediaFrame({super.key, required this.kind, required this.image, required this.width, this.empty});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final h = width / kind.ratio;
    final radius = kind == AqMediaKind.avatar ? width / 2 : (kind == AqMediaKind.logo ? width * 0.22 : AQRadius.large);
    return Container(
      width: width,
      height: h,
      decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(radius), border: Border.all(color: c.hairline, width: 1.5)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: image == null
            ? (empty ?? Center(child: AQIcon(kind == AqMediaKind.avatar ? 'user' : 'architecture', size: width * 0.3, color: c.accentDeep)))
            : AqMediaView(image: image!, kind: kind),
      ),
    );
  }
}

/// Reads a picture with the one shared picker, checking it is a JPG or PNG. Returns null if the person
/// cancelled; throws [AqMediaError] with a message key if the file is not usable.
class AqMediaError implements Exception {
  final String key;
  const AqMediaError(this.key);
}

Future<AqMediaImage?> pickAqMedia(WidgetRef ref) async {
  final d = await ref.read(documentPickerProvider).pick();
  if (d == null) return null;
  final isPdf = d.bytes.length >= 4 && d.bytes[0] == 0x25 && d.bytes[1] == 0x50;
  if (d.bytes.isEmpty || isPdf || !hasAllowedSignature(d.bytes)) throw const AqMediaError('pp.err.type');
  return AqMediaImage(d.bytes);
}

/// The field every screen uses: the framed preview, Add or Change, Remove. It owns no state: the containing
/// screen holds the draft and saves it, so a picture is never applied before the person confirms.
class AqMediaField extends ConsumerStatefulWidget {
  final AqMediaKind kind;
  final AqMediaImage? value;
  final ValueChanged<AqMediaImage?> onChanged;
  final double? width;
  const AqMediaField({super.key, required this.kind, required this.value, required this.onChanged, this.width});

  @override
  ConsumerState<AqMediaField> createState() => _AqMediaFieldState();
}

class _AqMediaFieldState extends ConsumerState<AqMediaField> {
  bool _picking = false;
  String? _error;

  Future<void> _add() async {
    final f = FlowStrings.of(context);
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await pickAqMedia(ref);
      if (!mounted) return;
      setState(() => _picking = false);
      if (picked == null) return;
      final framed = await showAqMediaEditor(context, kind: widget.kind, image: picked);
      if (framed != null) widget.onChanged(framed);
    } on AqMediaError catch (e) {
      if (mounted) {
        setState(() {
          _picking = false;
          _error = f.t(e.key);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _picking = false;
          _error = f.t('pp.err.pick');
        });
      }
    }
  }

  Future<void> _sheet() async {
    final f = FlowStrings.of(context);
    final has = widget.value != null;
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: AQGlass(
            radius: 24,
            blur: 20,
            fill: 0.86,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: AQSpacing.x3),
              Text(f.t(widget.kind.titleKey), style: AQTypography.of(ctx, AQText.titleMedium)),
              const SizedBox(height: AQSpacing.x2),
              _SheetRow(icon: 'plus', label: f.t('media.device'), onTap: () => Navigator.pop(ctx, 'device')),
              if (has) _SheetRow(icon: 'edit', label: f.t('media.reframe'), onTap: () => Navigator.pop(ctx, 'reframe')),
              if (has) _SheetRow(icon: 'close', label: f.t('pp.remove'), danger: true, onTap: () => Navigator.pop(ctx, 'remove')),
              _SheetRow(icon: 'chevron-left', label: f.t('common.cancel'), onTap: () => Navigator.pop(ctx)),
              const SizedBox(height: AQSpacing.x2),
            ]),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'device':
        await _add();
      case 'reframe':
        final framed = await showAqMediaEditor(context, kind: widget.kind, image: widget.value!);
        if (framed != null) widget.onChanged(framed);
      case 'remove':
        widget.onChanged(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final w = widget.width ?? (widget.kind == AqMediaKind.cover || widget.kind == AqMediaKind.portfolio ? 320.0 : 148.0);
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      LayoutBuilder(
        builder: (context, box) => AqMediaFrame(kind: widget.kind, image: widget.value, width: w > box.maxWidth ? box.maxWidth : w),
      ),
      const SizedBox(height: AQSpacing.x3),
      AQSecondaryButton(
        label: widget.value == null ? f.t('pp.add') : f.t('pp.change'),
        leadingIcon: widget.value == null ? 'plus' : 'edit',
        trailingChevron: false,
        loading: _picking,
        onPressed: _picking ? null : (widget.value == null ? _add : _sheet),
      ),
      if (_error != null) ...[
        const SizedBox(height: AQSpacing.x2),
        Text(_error!, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
      ],
    ]);
  }
}

class _SheetRow extends StatelessWidget {
  final String icon, label;
  final bool danger;
  final VoidCallback onTap;
  const _SheetRow({required this.icon, required this.label, required this.onTap, this.danger = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          child: Row(children: [
            AQIcon(icon, size: 20, color: danger ? c.danger : c.accentDeep),
            const SizedBox(width: AQSpacing.x3),
            Expanded(child: Text(label, style: AQTypography.of(context, AQText.bodyMedium, color: danger ? c.danger : c.ink))),
          ]),
        ),
      ),
    );
  }
}

/// Preview and frame editor: drag to reposition, slide to zoom, rotate, then confirm. Returns the framed
/// picture, or null if cancelled.
Future<AqMediaImage?> showAqMediaEditor(BuildContext context, {required AqMediaKind kind, required AqMediaImage image}) {
  return showDialog<AqMediaImage>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (_) => _AqMediaEditor(kind: kind, initial: image),
  );
}

class _AqMediaEditor extends StatefulWidget {
  final AqMediaKind kind;
  final AqMediaImage initial;
  const _AqMediaEditor({required this.kind, required this.initial});
  @override
  State<_AqMediaEditor> createState() => _AqMediaEditorState();
}

class _AqMediaEditorState extends State<_AqMediaEditor> {
  late AqMediaImage _img = widget.initial;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final maxW = MediaQuery.sizeOf(context).width;
    final frameW = (maxW - 2 * AQSpacing.x5 - 2 * AQSpacing.x4).clamp(160.0, 360.0);
    final frameH = frameW / widget.kind.ratio;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AQSpacing.x4),
      child: AQGlass(
        radius: 26,
        blur: 22,
        fill: 0.9,
        padding: const EdgeInsets.all(AQSpacing.x4),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(f.t(widget.kind.titleKey), style: AQTypography.of(context, AQText.titleMedium)),
          const SizedBox(height: AQSpacing.x1),
          Text(f.t('media.hint'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          const SizedBox(height: AQSpacing.x3),
          Semantics(
            image: true,
            label: f.t('pp.preview'),
            child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                // Dragging moves the picture under the frame: the opposite direction moves the focus point.
                _img = _img.copyWith(dx: (_img.dx - d.delta.dx / frameW * 2).clamp(-1.0, 1.0), dy: (_img.dy - d.delta.dy / frameH * 2).clamp(-1.0, 1.0));
              }),
              child: AqMediaFrame(kind: widget.kind, image: _img, width: frameW),
            ),
          ),
          const SizedBox(height: AQSpacing.x2),
          Row(children: [
            AQIcon('search', size: 16, color: c.inkSoft),
            Expanded(
              child: Semantics(
                label: f.t('pp.zoom'),
                child: Slider(value: _img.zoom, min: 1, max: 3, onChanged: (v) => setState(() => _img = _img.copyWith(zoom: v))),
              ),
            ),
            AQIconButton(icon: 'refresh', semanticsLabel: f.t('media.rotate'), onPressed: () => setState(() => _img = _img.copyWith(turns: (_img.turns + 1) % 4))),
          ]),
          const SizedBox(height: AQSpacing.x2),
          Row(children: [
            Expanded(child: AQSecondaryButton(label: f.t('common.cancel'), trailingChevron: false, compact: true, onPressed: () => Navigator.pop(context))),
            const SizedBox(width: AQSpacing.x2),
            Expanded(child: AQPrimaryButton(label: f.t('media.use'), trailingChevron: false, compact: true, onPressed: () => Navigator.pop(context, _img))),
          ]),
        ]),
      ),
    );
  }
}

/// Pictures chosen on this device are referred to like bundled ones, as `memory:N`, so a portfolio item, a
/// cover or a card can show them through the same image code. Registering the same picture twice reuses its id.
final Map<String, AqMediaImage> aqMemoryMedia = {};
final Expando<String> _memoryIds = Expando<String>('aq-memory-id');
int _memorySeq = 0;

String registerAqMedia(AqMediaImage image) {
  final known = _memoryIds[image];
  if (known != null) return known;
  final id = 'memory:${++_memorySeq}';
  _memoryIds[image] = id;
  aqMemoryMedia[id] = image;
  return id;
}
