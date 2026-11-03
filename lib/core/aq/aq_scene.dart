import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'aq_glass.dart';
import 'aq_primitives.dart';
import 'aq_tokens.dart';
import 'aq_typography.dart';

/// Full-bleed photograph with smooth tonal washes (never a cropped rectangle).
/// [quiet] lowers the photograph for technical steps where reading matters.
class AQBackdrop extends StatelessWidget {
  final String asset;
  final Alignment alignment;
  final bool quiet;
  const AQBackdrop({
    super.key,
    required this.asset,
    this.alignment = Alignment.bottomCenter,
    this.quiet = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final bg = c.background;
    final stops = quiet
        ? const [0.0, 0.4, 0.75, 1.0]
        : const [0.0, 0.42, 0.60, 0.70, 0.74, 0.84, 1.0];
    final alphas = quiet
        ? const [0.8, 0.66, 0.66, 0.84]
        : const [0.97, 0.94, 0.70, 0.0, 0.0, 0.78, 0.94];
    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: bg),
          Opacity(
            opacity: quiet ? (c.isDark ? 0.4 : 0.5) : (c.isDark ? 0.55 : 1),
            child: Image.asset(
              asset,
              fit: BoxFit.cover,
              alignment: alignment,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [for (final a in alphas) bg.withValues(alpha: a)],
                stops: stops,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fade + small rise driven by a shared controller (staggered by interval).
class AQReveal extends StatelessWidget {
  final Animation<double> animation;
  final double begin, end, dy;
  final Widget child;
  const AQReveal({
    super.key,
    required this.animation,
    required this.begin,
    required this.end,
    this.dy = 10,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final a = CurvedAnimation(
      parent: animation,
      curve: Interval(begin, end, curve: AQMotion.emphasized),
    );
    return AnimatedBuilder(
      animation: a,
      builder: (context, c) => Opacity(
        opacity: a.value,
        child: Transform.translate(
          offset: Offset(0, (1 - a.value) * dy),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Top bar: back (optional) and a quiet text action. 48 pt targets.
class AQTopBar extends StatelessWidget {
  final VoidCallback? onBack;
  final String? backLabel;
  final String? actionLabel;
  final String? actionSemantics;
  final VoidCallback? onAction;
  const AQTopBar({
    super.key,
    this.onBack,
    this.backLabel,
    this.actionLabel,
    this.actionSemantics,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AQControl.tap,
      child: Row(
        children: [
          if (onBack != null)
            AQIconButton(
              icon: 'chevron-left',
              semanticsLabel: backLabel ?? 'Back',
              onPressed: onBack,
            )
          else
            const SizedBox(width: AQControl.tap),
          const Spacer(),
          if (actionLabel != null)
            // A long action label (large text, Arabic) scales down instead of overflowing the bar.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerEnd,
                child: Semantics(
                  button: true,
                  focusable: true,
                  onFocus: () {},
                  label: actionSemantics ?? actionLabel,
                  excludeSemantics: true,
                  onTap: onAction,
                  child: AQTextButton(
                    label: actionLabel!,
                    trailingIcon: 'chevron-right',
                    onPressed: onAction,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Role / choice tile. Tonal at rest; selection = accent ring + warm tint + icon lift.
class AQChoiceTile extends StatelessWidget {
  final String icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  /// Optional shortcut chip in the corner (demo builds only): [onSkip] runs instead of [onTap].
  final String? skipLabel;
  final String? skipSemantics;
  final VoidCallback? onSkip;
  const AQChoiceTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
    this.skipLabel,
    this.skipSemantics,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final tile = _tile(context);
    if (onSkip == null || skipLabel == null) return tile;
    final c = AQColors.of(context);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        tile,
        PositionedDirectional(
          top: 0,
          end: 0,
          child: Semantics(
            button: true,
            focusable: true,
            onFocus: () {},
            label: skipSemantics ?? skipLabel,
            excludeSemantics: true,
      onTap: () {
                AQHaptics.confirm();
                onSkip!();
              },
            child: AQPressable(
              onTap: () {
                AQHaptics.confirm();
                onSkip!();
              },
              // Generous invisible hit area around a small pill.
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  AQSpacing.x3,
                  AQSpacing.x2,
                  AQSpacing.x2,
                  AQSpacing.x3,
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 28),
                  padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AQRadius.medium),
                    border: Border.all(color: c.accent.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        skipLabel!,
                        style: AQTypography.of(
                          context,
                          AQText.labelMedium,
                          color: c.accentDeep,
                        ),
                      ),
                      const SizedBox(width: 2),
                      AQIcon(
                        'chevron-right',
                        size: 12,
                        directional: true,
                        color: c.accentDeep,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: selected,
      label: title,
      hint: description,
      excludeSemantics: true,
      onTap: () {
          AQHaptics.selection();
          onTap();
        },
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          curve: AQMotion.standardCurve,
          padding: const EdgeInsetsDirectional.fromSTEB(
            AQSpacing.x4,
            AQSpacing.x4,
            AQSpacing.x3,
            AQSpacing.x4,
          ),
          decoration: BoxDecoration(
            color: selected ? c.surfaceSelected : c.surface,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            // Border only carries the selection signal (not decoration).
            border: Border.all(
              color: selected ? c.accent : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSlide(
                      duration: AQMotion.scaled(context, AQMotion.fast),
                      curve: AQMotion.standardCurve,
                      offset: Offset(0, selected ? -0.08 : 0),
                      child: AQIcon(
                        icon,
                        size: AQIconSize.role,
                        color: selected ? c.accentDeep : c.accent,
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    Text(
                      title,
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    const SizedBox(height: AQSpacing.x1),
                    Text(
                      description,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSlide(
                duration: AQMotion.scaled(context, AQMotion.fast),
                offset: Offset(
                  selected
                      ? (Directionality.of(context) == TextDirection.rtl
                            ? -0.2
                            : 0.2)
                      : 0,
                  0,
                ),
                child: AQIcon(
                  'chevron-right',
                  size: AQIconSize.small,
                  directional: true,
                  color: selected
                      ? c.accent
                      : c.inkFaint.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet: large top radius, drag handle, safe area, keyboard inset, tonal surface.
/// [useRootNavigator] puts the sheet above the shell's tab bar; use it from pages that live inside the shell.
Future<T?> showAQSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool dismissible = true,
  // Root by default: a sheet must cover the floating tab bar, not sit under it.
  bool useRootNavigator = true,
}) {
  final c = AQColors.of(context);
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: useRootNavigator,
    isScrollControlled: true,
    isDismissible: dismissible,
    enableDrag: dismissible,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66000000),
    sheetAnimationStyle: AnimationStyle(
      duration: AQMotion.sheet,
      reverseDuration: AQMotion.sheetReverse,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ),
    builder: (sheetContext) {
      final bottom = MediaQuery.of(sheetContext).viewInsets.bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AQRadius.large),
            ),
            boxShadow: AQElevation.modal,
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AQSpacing.x3),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.hairline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AQSpacing.x2),
                builder(sheetContext),
                const SizedBox(height: AQSpacing.x3),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Selectable row for sheets (language, filters, contextual choices).
class AQSheetRow extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;
  const AQSheetRow({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: selected,
      label: title,
      excludeSemantics: true,
      onTap: () {
          AQHaptics.selection();
          onTap();
        },
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        pressedScale: 0.99,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AQTypography.of(
                    context,
                    selected ? AQText.titleMedium : AQText.bodyLarge,
                  ),
                ),
              ),
              if (selected)
                AQIcon('check', size: AQIconSize.medium, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen transitions. Families: [AQRoute.forward] (shared axis: fade + small rise + very slight scale),
/// [AQRoute.fade] (calm cross-fade for same-level swaps).
class AQRoute {
  AQRoute._();

  /// Standard push: the new page arrives from the logical forward side (right in LTR, left in RTL)
  /// by [AQMotion.routeTravel] px while fading in; the page underneath drifts back a few px and
  /// fades. Pop plays the same motion in reverse. Reduced motion is a plain fade.
  static Page<T> forward<T>({required LocalKey key, required Widget child}) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: AQMotion.page,
        reverseTransitionDuration: AQMotion.standard,
        transitionsBuilder: forwardTransition,
      );

  /// The standard push motion, shared by router pages and [route].
  static Widget forwardTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondary,
    Widget child,
  ) {
    if (AQMotion.reduced(context))
      return FadeTransition(opacity: animation, child: child);
    final dir = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    final inCurve = animation.drive(CurveTween(curve: Curves.easeOutCubic));
    final outCurve = secondary.drive(CurveTween(curve: Curves.easeInOutCubic));
    return AnimatedBuilder(
      animation: Listenable.merge([animation, secondary]),
      child: child,
      builder: (context, child) {
        final dx =
            dir *
            (AQMotion.routeTravel * (1 - inCurve.value) - 6 * outCurve.value);
        final fadeIn = animation
            .drive(
              CurveTween(curve: const Interval(0, 0.75, curve: Curves.easeOut)),
            )
            .value;
        final fadeOut =
            1 -
            secondary
                .drive(
                  CurveTween(
                    curve: const Interval(0, 0.6, curve: Curves.easeIn),
                  ),
                )
                .value;
        return Opacity(
          opacity: (fadeIn * fadeOut).clamp(0.0, 1.0),
          child: Transform.translate(offset: Offset(dx, 0), child: child),
        );
      },
    );
  }

  /// For screens opened with `Navigator.push` (they carry an object, so they have no URL): the same
  /// motion as every router page, instead of the platform default.
  static Route<T> route<T>(Widget child) => PageRouteBuilder<T>(
    transitionDuration: AQMotion.page,
    reverseTransitionDuration: AQMotion.standard,
    pageBuilder: (context, animation, secondary) => child,
    transitionsBuilder: forwardTransition,
  );

  /// Main tabs: a quick cross-fade, no travel (tabs are peers, not a journey).
  static Page<T> tab<T>({required LocalKey key, required Widget child}) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: AQMotion.fast,
        reverseTransitionDuration: AQMotion.fast,
        transitionsBuilder: (context, animation, secondary, child) {
          if (AQMotion.reduced(context)) return child;
          // Fade-through: the outgoing tab clears in the first half, the incoming one fades in during
          // the second, so two pages' text never sits on top of each other.
          final fadeIn = animation.drive(
            CurveTween(curve: const Interval(0.4, 1, curve: Curves.easeOut)),
          );
          final fadeOut = secondary.drive(
            CurveTween(curve: const Interval(0, 0.5, curve: Curves.easeIn)),
          );
          return AnimatedBuilder(
            animation: Listenable.merge([animation, secondary]),
            child: child,
            builder: (context, child) => Opacity(
              opacity: (fadeIn.value * (1 - fadeOut.value)).clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
      );

  /// Reading / detail surfaces: rises from below like a sheet, leaves the same way.
  static Page<T> sheet<T>({required LocalKey key, required Widget child}) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: AQMotion.slow,
        reverseTransitionDuration: AQMotion.standard,
        transitionsBuilder: (context, animation, secondary, child) {
          if (AQMotion.reduced(context))
            return FadeTransition(opacity: animation, child: child);
          final curve = CurvedAnimation(
            parent: animation,
            curve: AQMotion.emphasized,
          );
          return FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: animation, curve: const Interval(0, 0.6)),
            ),
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curve),
              child: child,
            ),
          );
        },
      );

  /// Milestones (approval, workspace): a calm opening-out, slightly more scale than [forward].
  static Page<T> hero<T>({required LocalKey key, required Widget child}) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: AQMotion.standard,
        transitionsBuilder: (context, animation, secondary, child) {
          if (AQMotion.reduced(context))
            return FadeTransition(opacity: animation, child: child);
          final curve = CurvedAnimation(
            parent: animation,
            curve: AQMotion.emphasized,
          );
          return FadeTransition(
            opacity: curve,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(curve),
              child: child,
            ),
          );
        },
      );

  static Page<T> fade<T>({required LocalKey key, required Widget child}) =>
      CustomTransitionPage<T>(
        key: key,
        child: child,
        transitionDuration: AQMotion.standard,
        transitionsBuilder: (context, animation, secondary, child) =>
            FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: AQMotion.standardCurve,
              ),
              child: child,
            ),
      );
}

/// Floating glass navigation (Home / Explore / Activity / Account): the only glass in the app.
/// Minimises while scrolling down and expands on scroll up or interaction.
class AQNavController extends ChangeNotifier {
  bool _compact = false;
  bool get compact => _compact;
  void setCompact(bool v) {
    if (v != _compact) {
      _compact = v;
      notifyListeners();
    }
  }

  /// Feed from a ScrollNotification listener.
  bool onScroll(ScrollNotification n) {
    if (n is UserScrollNotification) {
      if (n.direction == ScrollDirection.reverse) setCompact(true);
      if (n.direction == ScrollDirection.forward) setCompact(false);
    }
    return false;
  }
}

class AQNavItem {
  final String icon, label;
  const AQNavItem(this.icon, this.label);
}

class AQGlassNav extends StatelessWidget {
  final List<AQNavItem> items;
  final int index;
  final ValueChanged<int> onSelected;
  final AQNavController controller;
  const AQGlassNav({
    super.key,
    required this.items,
    required this.index,
    required this.onSelected,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final compact = controller.compact;
        return SafeArea(
          minimum: const EdgeInsets.only(bottom: AQSpacing.x3),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: compact ? () => controller.setCompact(false) : null,
              child: AnimatedContainer(
                duration: AQMotion.scaled(context, AQMotion.standard),
                curve: AQMotion.spring,
                margin: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width < 380 ? AQSpacing.x1 : AQSpacing.x2),
                height: compact ? 52 : 68,
                constraints: BoxConstraints(maxWidth: compact ? 232 : (items.length > 5 ? 500 : 420)),
                child: AQGlass(
                  radius: compact ? 26 : AQRadius.large,
                  blur: 24,
                  // Floating over photographs and dark sections, the bar must stay readable: a mostly
                  // solid warm sheet with a hint of the content behind, not a see-through one.
                  fill: 0.88,
                  child: SizedBox.expand(
                      child: LayoutBuilder(
                        builder: (context, box) {
                          final w = box.maxWidth / items.length;
                          final pillColor = c.accent.withValues(
                            alpha: c.isDark ? 0.34 : 0.28,
                          );
                          return Stack(
                            children: [
                              // One indicator that slides to the selected tab (start-aligned, so it mirrors in RTL).
                              AnimatedPositionedDirectional(
                                key: const ValueKey('nav-indicator'),
                                duration: AQMotion.scaled(
                                  context,
                                  AQMotion.fast,
                                ),
                                curve: Curves.easeInOutCubic,
                                start: index * w + 4,
                                width: w - 8,
                                top: 5,
                                bottom: 5,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: pillColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  for (var i = 0; i < items.length; i++)
                                    Expanded(
                                      child: Semantics(
                                        button: true,
                                        focusable: true,
                                        onFocus: () {},
                                        selected: i == index,
                                        label: items[i].label,
                                        excludeSemantics: true,
      onTap: () {
                                            AQHaptics.selection();
                                            onSelected(i);
                                          },
                                        child: AQPressable(
                                          onTap: () {
                                            AQHaptics.selection();
                                            onSelected(i);
                                          },
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 1,
                                              vertical: 5,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                AnimatedScale(
                                                  scale: i == index ? 1 : 0.92,
                                                  duration: AQMotion.scaled(
                                                    context,
                                                    AQMotion.icon,
                                                  ),
                                                  curve: Curves.easeOutCubic,
                                                  child:
                                                      TweenAnimationBuilder<
                                                        Color?
                                                      >(
                                                        tween: ColorTween(
                                                          end: i == index
                                                              ? c.accentDeep
                                                              : c.inkSoft,
                                                        ),
                                                        duration:
                                                            AQMotion.scaled(
                                                              context,
                                                              AQMotion.icon,
                                                            ),
                                                        builder:
                                                            (
                                                              context,
                                                              col,
                                                              _,
                                                            ) => AQIcon(
                                                              items[i].icon,
                                                              size: AQIconSize
                                                                  .medium,
                                                              color: col,
                                                            ),
                                                      ),
                                                ),
                                                if (!compact) ...[
                                                  const SizedBox(height: 3),
                                                  FittedBox(
                                                    fit: BoxFit.scaleDown,
                                                    child: AnimatedDefaultTextStyle(
                                                      duration: AQMotion.scaled(
                                                        context,
                                                        AQMotion.icon,
                                                      ),
                                                      style:
                                                          AQTypography.of(
                                                            context,
                                                            AQText.labelMedium,
                                                            color: i == index
                                                                ? c.accentDeep
                                                                : c.inkSoft,
                                                          ).copyWith(
                                                            // Five items share the bar: a hair smaller, never scaled to an unreadable size.
                                                            fontSize: items.length > 4 ? 10.5 : 11,
                                                            letterSpacing: -0.15,
                                                            fontWeight:
                                                                i == index
                                                                ? FontWeight
                                                                      .w700
                                                                : FontWeight
                                                                      .w500,
                                                          ),
                                                      child: Text(
                                                        items[i].label,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// AnimatedSize that is safe under reduced motion. Flutter asserts when an AnimatedSize with a zero
/// duration changes size, so with reduced motion the child is placed directly and just snaps.
class AQAnimatedSize extends StatelessWidget {
  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final Widget child;
  const AQAnimatedSize({
    super.key,
    this.duration = AQMotion.standard,
    this.curve = Curves.easeOutCubic,
    this.alignment = Alignment.topCenter,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (AQMotion.reduced(context)) return child;
    return AnimatedSize(
      duration: duration,
      curve: curve,
      alignment: alignment,
      child: child,
    );
  }
}

/// Swaps a multi-step form body with a short directional slide and fade. [forward] is the logical
/// direction of travel (Next = true, Back = false) and mirrors in RTL. Keep [stepKey] stable per
/// step so the right child animates; values live outside this widget so nothing is lost.
class AQStepSwitcher extends StatelessWidget {
  final Object stepKey;
  final bool forward;
  final Widget child;
  const AQStepSwitcher({
    super.key,
    required this.stepKey,
    required this.forward,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final reduced = AQMotion.reduced(context);
    final dir =
        (Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0) *
        (forward ? 1.0 : -1.0);
    final currentKey = ValueKey<Object>(stepKey);
    return AQAnimatedSize(
      duration: AQMotion.formStep,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: reduced ? Duration.zero : AQMotion.formStep,
        reverseDuration: reduced ? Duration.zero : AQMotion.formStep,
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: AlignmentDirectional.topStart,
          children: [...previous, ?current],
        ),
        transitionBuilder: (child, animation) {
          final incoming = child.key == currentKey;
          // Incoming starts stepTravel px behind the direction of travel; outgoing leaves ahead of it.
          final offset = animation.drive(
            Tween<Offset>(
              begin: Offset(
                incoming
                    ? dir * AQMotion.stepTravel
                    : -dir * AQMotion.stepTravel,
                0,
              ),
              end: Offset.zero,
            ),
          );
          return FadeTransition(
            opacity: animation,
            child: AnimatedBuilder(
              animation: offset,
              child: child,
              builder: (context, c) =>
                  Transform.translate(offset: offset.value, child: c),
            ),
          );
        },
        child: KeyedSubtree(key: currentKey, child: child),
      ),
    );
  }
}

/// A heart that pops once (0.9 to 1.08 to 1.0) when [saved] actually changes. It never animates on
/// first build, never loops, and is static under reduced motion.
class AQHeart extends StatefulWidget {
  final bool saved;
  final double size;
  final Color savedColor;
  final Color idleColor;
  const AQHeart({
    super.key,
    required this.saved,
    this.size = 22,
    required this.savedColor,
    required this.idleColor,
  });
  @override
  State<AQHeart> createState() => _AQHeartState();
}

class _AQHeartState extends State<AQHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.9,
        end: 1.08,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 45,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.08,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeInOut)),
      weight: 55,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(AQHeart old) {
    super.didUpdateWidget(old);
    if (old.saved != widget.saved && !AQMotion.reduced(context))
      _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => Transform.scale(
      scale: _c.isAnimating ? _scale.value : 1.0,
      child: child,
    ),
    child: TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: widget.saved ? widget.savedColor : widget.idleColor,
      ),
      duration: AQMotion.scaled(context, AQMotion.icon),
      builder: (context, col, _) => Icon(
        widget.saved ? Icons.favorite : Icons.favorite_border,
        size: widget.size,
        color: col,
      ),
    ),
  );
}

/// Convenience used by screens: pop if possible, else go to [fallback].
void aqBack(BuildContext context, String fallback) =>
    context.canPop() ? context.pop() : context.go(fallback);
