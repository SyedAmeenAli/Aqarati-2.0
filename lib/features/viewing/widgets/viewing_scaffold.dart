import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../entry/widgets/entry_common.dart' show MasterLogo;
import 'viewing_format.dart';

/// Shared shell for the viewing journey: brand context in the top bar, an editorial
/// title (large and centred for emotional screens, smaller for task screens), a
/// scrolling body, and a pinned action area that respects the safe area.
/// How much of the bottom of the screen the shared customer navigation covers. Zero outside the
/// shell (focused flows); inside it, scrolling pages leave room and sticky action bars sit above it.
class AQShellInset extends InheritedWidget {
  final double height;
  const AQShellInset({super.key, required this.height, required super.child});
  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AQShellInset>()?.height ?? 0;
  @override
  bool updateShouldNotify(AQShellInset old) => old.height != height;
}

class AQViewingScaffold extends StatefulWidget {
  final String? title;
  final String? subtitle;
  final Widget? hero;
  /// Property photograph washed behind the top of emotional screens.
  final String? washImage;
  final List<Widget> children;
  final Widget? bottom;
  final VoidCallback? onBack;
  final String backLabel;
  final bool showBack;
  final bool emotional;
  final Widget? trailing;
  /// Content column width; tablet and desktop screens that need more room than a phone column pass a larger value.
  final double? maxWidth;
  const AQViewingScaffold({
    super.key,
    this.title,
    this.subtitle,
    this.hero,
    this.washImage,
    required this.children,
    this.bottom,
    this.onBack,
    this.backLabel = 'Back',
    this.showBack = true,
    this.emotional = false,
    this.trailing,
    this.maxWidth,
  });

  @override
  State<AQViewingScaffold> createState() => _AQViewingScaffoldState();
}

class _AQViewingScaffoldState extends State<AQViewingScaffold> with SingleTickerProviderStateMixin {
  late final AnimationController _enter = AnimationController(vsync: this, duration: AQMotion.reveal);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AQMotion.reduced(context) ? _enter.value = 1 : _enter.forward();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final centered = widget.emotional;
    final inset = AQShellInset.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: c.isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: c.isDark ? Brightness.dark : Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(fit: StackFit.expand, children: [
          if (widget.washImage != null) _Wash(asset: widget.washImage!) else const AQBackdrop(asset: 'assets/entry/oman_terrace_2k.jpg', quiet: true),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: widget.maxWidth ?? AQSpacing.maxContent + AQSpacing.gutter * 2),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
                    child: SizedBox(
                      height: AQControl.tap,
                      child: Row(children: [
                        if (widget.showBack) AQIconButton(icon: 'chevron-left', semanticsLabel: widget.backLabel, onPressed: widget.onBack ?? () => Navigator.of(context).maybePop()) else const SizedBox(width: AQSpacing.x2),
                        const SizedBox(width: AQSpacing.x1),
                        SizedBox(height: 46, child: FittedBox(fit: BoxFit.contain, child: MasterLogo(width: 80))),
                        const Spacer(),
                        if (widget.trailing != null) widget.trailing!,
                      ]),
                    ),
                  ),
                  Expanded(
                    child: ShaderMask(
                      blendMode: BlendMode.dstIn,
                      shaderCallback: (r) => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, 0.96, 1]).createShader(r),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x6 + (widget.bottom == null ? inset : 0)),
                        child: Column(crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
                          if (widget.hero != null) ...[AQReveal(animation: _enter, begin: 0, end: 0.5, dy: 6, child: widget.hero!), const SizedBox(height: AQSpacing.x4)],
                          if (widget.title != null)
                            AQReveal(
                              animation: _enter,
                              begin: 0.06,
                              end: 0.55,
                              dy: 8,
                              child: Semantics(header: true, child: Text(widget.title!, textAlign: centered ? TextAlign.center : null, style: AQTypography.of(context, centered ? AQText.displaySmall : AQText.headlineLarge))),
                            ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: AQSpacing.x2),
                            AQReveal(animation: _enter, begin: 0.14, end: 0.62, dy: 6, child: Text(widget.subtitle!, textAlign: centered ? TextAlign.center : null, style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
                          ],
                          SizedBox(height: widget.title == null && widget.hero == null ? AQSpacing.x1 : AQSpacing.x5),
                          AQReveal(animation: _enter, begin: 0.2, end: 0.85, dy: 8, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children)),
                        ]),
                      ),
                    ),
                  ),
                  if (widget.bottom != null) AQReveal(animation: _enter, begin: 0.5, end: 1, dy: 6, child: widget.bottom!),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Property photograph fading into the page: emotional screens only.
class _Wash extends StatelessWidget {
  final String asset;
  const _Wash({required this.asset});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final bg = c.background;
    return RepaintBoundary(
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(color: bg),
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 380,
            width: double.infinity,
            child: Opacity(
              opacity: c.isDark ? 0.42 : 0.40,
              child: Image.asset(asset, fit: BoxFit.cover, alignment: Alignment.center, cacheWidth: 900, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg.withValues(alpha: 0.35), bg.withValues(alpha: 0.82), bg], stops: const [0, 0.32, 0.5]),
          ),
        ),
      ]),
    );
  }
}

/// Pinned action surface. Primary sits at the trailing end (or on top when stacked);
/// the optional [summary] row carries the selection the action commits.
class AQBottomActionBar extends StatelessWidget {
  final Widget? summary;
  final Widget primary;
  final Widget? secondary;
  final String? footnote;
  /// Stack the actions (primary on top) when the labels are long; otherwise they sit side by side.
  final bool stack;
  /// Keep both actions on one row on narrow phones (the caller supplies short labels). Large text still stacks.
  final bool compact;
  const AQBottomActionBar({super.key, this.summary, required this.primary, this.secondary, this.footnote, this.stack = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final inset = AQShellInset.of(context);
    final stacked = stack || aqLargeText(context) || (!compact && MediaQuery.sizeOf(context).width < 340);
    final buttons = secondary == null
        ? primary
        : stacked
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [primary, const SizedBox(height: AQSpacing.x2), secondary!])
            : Row(children: [Expanded(flex: compact ? 2 : 1, child: secondary!), SizedBox(width: compact ? AQSpacing.x2 : AQSpacing.x3), Expanded(flex: compact ? 3 : 1, child: primary)]);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AQRadius.large)),
        boxShadow: [BoxShadow(color: const Color(0x1A2D2823), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        bottom: inset == 0,
        minimum: const EdgeInsets.only(bottom: AQSpacing.x2),
        child: Padding(
          padding: EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.gutter, AQSpacing.x1 + inset),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (summary != null) ...[summary!, const SizedBox(height: AQSpacing.x3)],
            buttons,
            // At large text the bar must leave the content room; the footnote is reassurance, not a control.
            if (footnote != null && !aqDenseBar(context)) ...[
              const SizedBox(height: AQSpacing.x2),
              Row(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon('info', size: 16, color: c.inkFaint)),
                const SizedBox(width: AQSpacing.x2),
                Flexible(child: Text(footnote!, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint))),
              ]),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Secondary action for the pinned bar: tonal fill that stays visible on the raised surface.
class AQBarSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? leadingIcon;
  final Color? foreground;
  const AQBarSecondaryButton({super.key, required this.label, required this.onPressed, this.leadingIcon, this.foreground});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AQSecondaryButton(label: label, onPressed: onPressed, leadingIcon: leadingIcon, trailingChevron: false, foreground: foreground, background: c.surfaceSelected);
  }
}
