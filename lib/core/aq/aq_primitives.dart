import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'aq_tokens.dart';
import 'aq_typography.dart';

/// One icon family: 24 pt grid, 1.6 stroke, round caps. Names map to assets/icons/aq/*.svg.
class AQIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;

  /// Mirror horizontally in RTL (chevrons, back arrows).
  final bool directional;
  const AQIcon(
    this.name, {
    super.key,
    this.size = AQIconSize.medium,
    this.color,
    this.directional = false,
  });

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final c = color ?? AQColors.of(context).ink;
    Widget icon = SvgPicture.asset(
      'assets/icons/aq/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      // A name without a matching asset (or an asset that fails to parse) shows a neutral ring, never a blank gap.
      errorBuilder: (_, _, _) => Icon(Icons.circle_outlined, key: const ValueKey('aq-icon-fallback'), size: size, color: c),
    );
    if (directional && rtl) icon = Transform.flip(flipX: true, child: icon);
    return ExcludeSemantics(child: icon);
  }
}

/// Centralised haptics: meaningful moments only.
class AQHaptics {
  AQHaptics._();
  static void selection() => HapticFeedback.selectionClick();
  static void confirm() => HapticFeedback.lightImpact();
  static void success() => HapticFeedback.mediumImpact();
}

/// Shared press behaviour: 1.00 to 0.985, no bounce.
class AQPressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;
  final double pressedScale;
  const AQPressable({
    super.key,
    required this.onTap,
    required this.child,
    this.pressedScale = 0.985,
  });

  @override
  State<AQPressable> createState() => _AQPressableState();
}

class _AQPressableState extends State<AQPressable> {
  bool _down = false;
  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.pressedScale : 1,
        // Press starts at once; release settles slightly slower.
        duration: AQMotion.scaled(
          context,
          _down ? AQMotion.tapDown : AQMotion.tapUp,
        ),
        curve: AQMotion.standardCurve,
        child: widget.child,
      ),
    );
  }
}

enum _BtnKind { primary, secondary }

class _AQButton extends StatelessWidget {
  final _BtnKind kind;
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;
  final String? semanticsLabel;
  final String? leadingIcon;
  final bool trailingChevron;

  /// Optional tone override (destructive actions); null keeps the standard look.
  final Color? background, foreground;
  const _AQButton({
    required this.kind,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
    this.semanticsLabel,
    this.leadingIcon,
    this.trailingChevron = true,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final enabled = onPressed != null && !loading;
    final primary = kind == _BtnKind.primary;
    final fg =
        foreground ??
        (primary
            ? (onPressed == null && c.isDark ? c.inkSoft : c.onAccent)
            : c.ink);
    final bg =
        background ??
        (primary
            ? (onPressed == null ? c.accentDisabled : c.accent)
            : c.surface);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      enabled: onPressed != null,
      label: semanticsLabel ?? label,
      excludeSemantics: true,
      // Without this the button has no tap action for a screen reader or the keyboard.
      onTap: enabled ? onPressed : null,
      child: AQPressable(
        onTap: enabled ? onPressed : null,
        pressedScale: 0.98,
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          constraints: BoxConstraints(
            minHeight: compact ? AQControl.buttonCompact : AQControl.button,
          ),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: AQSpacing.x5,
            vertical: compact ? AQSpacing.x2 : AQSpacing.x3,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            // Primary rests on a subtle lift only; secondary is purely tonal (no border).
            boxShadow: primary && onPressed != null
                ? AQElevation.subtle
                : AQElevation.none,
          ),
          child: leadingIcon != null && !trailingChevron
              // Icon sits with the label (no reserved side columns), so long labels keep their width.
              ? Center(
                  child: loading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: fg,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AQIcon(
                              leadingIcon!,
                              size: AQIconSize.medium,
                              color: fg,
                            ),
                            const SizedBox(width: AQSpacing.x2),
                            Flexible(
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: AQTypography.of(
                                  context,
                                  AQText.labelLarge,
                                  color: fg,
                                ),
                              ),
                            ),
                          ],
                        ),
                )
              : Row(
                  children: [
                    SizedBox(
                      width: leadingIcon == null && !trailingChevron
                          ? 0
                          : AQSpacing.x6,
                      child: leadingIcon == null
                          ? null
                          : AQIcon(
                              leadingIcon!,
                              size: AQIconSize.medium,
                              color: fg,
                            ),
                    ),
                    Expanded(
                      child: Center(
                        child: loading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: fg,
                                ),
                              )
                            : Text(
                                label,
                                textAlign: TextAlign.center,
                                style: AQTypography.of(
                                  context,
                                  AQText.labelLarge,
                                  color: fg,
                                ),
                              ),
                      ),
                    ),
                    SizedBox(
                      width: leadingIcon == null && !trailingChevron
                          ? 0
                          : AQSpacing.x6,
                      child: trailingChevron
                          ? AQIcon(
                              'chevron-right',
                              size: AQIconSize.medium,
                              color: fg,
                              directional: true,
                            )
                          : null,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class AQPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, compact, trailingChevron;
  final String? semanticsLabel, leadingIcon;
  final Color? background, foreground;
  const AQPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
    this.semanticsLabel,
    this.trailingChevron = true,
    this.leadingIcon,
    this.background,
    this.foreground,
  });
  @override
  Widget build(BuildContext context) => _AQButton(
    kind: _BtnKind.primary,
    label: label,
    onPressed: onPressed,
    loading: loading,
    compact: compact,
    semanticsLabel: semanticsLabel,
    trailingChevron: trailingChevron,
    leadingIcon: leadingIcon,
    background: background,
    foreground: foreground,
  );
}

class AQSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading, compact, trailingChevron;
  final String? semanticsLabel, leadingIcon;
  final Color? foreground, background;
  const AQSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.compact = false,
    this.semanticsLabel,
    this.leadingIcon,
    this.trailingChevron = true,
    this.foreground,
    this.background,
  });
  @override
  Widget build(BuildContext context) => _AQButton(
    kind: _BtnKind.secondary,
    label: label,
    onPressed: onPressed,
    loading: loading,
    compact: compact,
    semanticsLabel: semanticsLabel,
    leadingIcon: leadingIcon,
    trailingChevron: trailingChevron,
    foreground: foreground,
    background: background,
  );
}

class AQTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final String? trailingIcon;
  final Color? color;
  const AQTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.trailingIcon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final fg = color ?? c.inkSoft;
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      enabled: onPressed != null,
      label: label,
      excludeSemantics: true,
      onTap: onPressed,
      child: AQPressable(
        onTap: onPressed,
        pressedScale: 0.97,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AQControl.tap,
            minWidth: AQControl.tap,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: AQTypography.of(
                      context,
                      AQText.titleSmall,
                      color: fg,
                    ),
                  ),
                ),
                if (trailingIcon != null) ...[
                  const SizedBox(width: 2),
                  AQIcon(
                    trailingIcon!,
                    size: AQIconSize.small,
                    color: fg,
                    directional: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AQIconButton extends StatelessWidget {
  final String icon;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final bool directional;
  final Color? color;
  const AQIconButton({
    super.key,
    required this.icon,
    required this.semanticsLabel,
    required this.onPressed,
    this.directional = true,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: semanticsLabel,
      excludeSemantics: true,
      onTap: onPressed,
      child: AQPressable(
        onTap: onPressed,
        pressedScale: 0.92,
        child: SizedBox(
          width: AQControl.tap,
          height: AQControl.tap,
          child: Center(
            child: AQIcon(
              icon,
              size: AQIconSize.large,
              directional: directional,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// Semantic surfaces. Each has a reason to exist.
enum AQSurfaceKind {
  /// Resting tonal fill on the page (fields, choice tiles).
  secondary,

  /// Raised/solid (sheets, modal content).
  elevated,

  /// Grouped content block (one surface, hairline-separated rows).
  grouped,
}

class AQSurface extends StatelessWidget {
  final AQSurfaceKind kind;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  const AQSurface({
    super.key,
    this.kind = AQSurfaceKind.secondary,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = AQRadius.medium,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    // Cards sit on photograph backdrops: a near-solid raised surface with a hairline reads as a card
    // (the old translucent fill washed out against the picture).
    final (color, shadow) = switch (kind) {
      AQSurfaceKind.secondary => (c.surfaceRaised.withValues(alpha: 0.94), AQElevation.subtle),
      AQSurfaceKind.elevated => (c.surfaceRaised, AQElevation.floating),
      AQSurfaceKind.grouped => (c.surfaceRaised.withValues(alpha: 0.94), AQElevation.none),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.hairline),
        boxShadow: shadow,
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
