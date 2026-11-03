import 'package:flutter/material.dart';

/// AQARATI Experience System: single source of truth for design tokens.
/// Brand values come from the brand book (mocha #825C3F, ivory #ECE3D7,
/// deep mocha #674830, ink #2D2823); dark values are derived, not inverted.

/// Semantic colour set. Read with [AQColors.of].
@immutable
class AQColors {
  final Brightness brightness;

  /// Page background (calm ivory / deep warm near-black).
  final Color background;

  /// Resting tonal surface on the background (fields, choice tiles).
  final Color surface;

  /// Raised tonal surface (sheets, selected tint).
  final Color surfaceRaised;

  /// Selected / pressed tint.
  final Color surfaceSelected;
  final Color ink;
  final Color inkSoft;
  final Color inkFaint;
  final Color hairline;
  final Color accent;
  final Color accentDeep;
  final Color onAccent;
  final Color accentDisabled;
  final Color danger;
  final Color success;

  /// Restrained amber for attention states (decline, reschedule); never an alarm red.
  final Color warning;

  const AQColors._({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSelected,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.hairline,
    required this.accent,
    required this.accentDeep,
    required this.onAccent,
    required this.accentDisabled,
    required this.danger,
    required this.success,
    required this.warning,
  });

  static const light = AQColors._(
    brightness: Brightness.light,
    background: Color(0xFFEDE1D4),
    surface: Color(0xB8FBF7F1),
    surfaceRaised: Color(0xFFFBF7F1),
    surfaceSelected: Color(0xFFF6EADB),
    ink: Color(0xFF2D2823),
    inkSoft: Color(0xFF655C52),
    inkFaint: Color(0xFF6A5F54),
    hairline: Color(0x33655C52),
    accent: Color(0xFF825C3F),
    accentDeep: Color(0xFF674830),
    onAccent: Color(0xFFFFFFFF),
    accentDisabled: Color(0xFFB09A86),
    danger: Color(0xFFA2402E),
    success: Color(0xFF4C6B38),
    warning: Color(0xFF8A5A1F),
  );

  static const dark = AQColors._(
    brightness: Brightness.dark,
    background: Color(0xFF1A1613),
    surface: Color(0xB8272019),
    surfaceRaised: Color(0xFF2A231D),
    surfaceSelected: Color(0xFF3A2E24),
    ink: Color(0xFFF1E8DB),
    inkSoft: Color(0xFFC3B6A5),
    inkFaint: Color(0xFF93877A),
    hairline: Color(0x33F1E8DB),
    accent: Color(0xFFB98A64),
    accentDeep: Color(0xFFD1A47F),
    onAccent: Color(0xFF1A1613),
    accentDisabled: Color(0xFF6B5545),
    danger: Color(0xFFE08A78),
    success: Color(0xFF9DB98A),
    warning: Color(0xFFD9A86A),
  );

  /// The colours for this subtree. Inside [AQThemeTransition] this is the (possibly mid-transition)
  /// interpolated palette, so every surface fades together; without it the palette follows the
  /// Material brightness, as before.
  static AQColors of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AQColorScope>();
    if (scope != null) return scope.colors;
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }

  /// Linear interpolation between two palettes. Brightness flips at the midpoint.
  static AQColors lerp(AQColors a, AQColors b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    Color c(Color x, Color y) => Color.lerp(x, y, t)!;
    return AQColors._(
      brightness: t < 0.5 ? a.brightness : b.brightness,
      background: c(a.background, b.background),
      surface: c(a.surface, b.surface),
      surfaceRaised: c(a.surfaceRaised, b.surfaceRaised),
      surfaceSelected: c(a.surfaceSelected, b.surfaceSelected),
      ink: c(a.ink, b.ink),
      inkSoft: c(a.inkSoft, b.inkSoft),
      inkFaint: c(a.inkFaint, b.inkFaint),
      hairline: c(a.hairline, b.hairline),
      accent: c(a.accent, b.accent),
      accentDeep: c(a.accentDeep, b.accentDeep),
      onAccent: c(a.onAccent, b.onAccent),
      accentDisabled: c(a.accentDisabled, b.accentDisabled),
      danger: c(a.danger, b.danger),
      success: c(a.success, b.success),
      warning: c(a.warning, b.warning),
    );
  }

  bool get isDark => brightness == Brightness.dark;
}

/// Carries the current palette down the tree. See [AQColors.of] and [AQThemeTransition].
class AQColorScope extends InheritedWidget {
  final AQColors colors;
  const AQColorScope({super.key, required this.colors, required super.child});
  @override
  bool updateShouldNotify(AQColorScope old) => !identical(colors, old.colors);
}

/// Animates the palette when the in-app theme changes (colours, text, borders, icons, fields and
/// bars all read [AQColors.of]), so nothing snaps. The route, scroll position, form values and
/// role are untouched because only colours change. Reduced motion shortens it to a brief fade.
class AQThemeTransition extends StatefulWidget {
  final ThemeMode mode;
  final Widget child;
  const AQThemeTransition({super.key, required this.mode, required this.child});
  @override
  State<AQThemeTransition> createState() => _AQThemeTransitionState();
}

class _AQThemeTransitionState extends State<AQThemeTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AQMotion.theme,
  );
  bool _first = true;

  double _target(BuildContext context) => switch (widget.mode) {
    ThemeMode.dark => 1,
    ThemeMode.light => 0,
    ThemeMode.system =>
      MediaQuery.platformBrightnessOf(context) == Brightness.dark ? 1 : 0,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final target = _target(context);
    if (_first) {
      _first = false;
      _c.value = target;
    } else if (_c.value != target) {
      final reduced = AQMotion.reduced(context);
      _c.animateTo(
        target,
        duration: reduced ? AQMotion.themeReduced : AQMotion.theme,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void didUpdateWidget(AQThemeTransition old) {
    super.didUpdateWidget(old);
    if (old.mode != widget.mode) didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) => AQColorScope(
      colors: AQColors.lerp(AQColors.light, AQColors.dark, _c.value),
      child: child!,
    ),
  );
}

/// 4-pt rhythm.
class AQSpacing {
  AQSpacing._();
  static const double x1 = 4,
      x2 = 8,
      x3 = 12,
      x4 = 16,
      x5 = 20,
      x6 = 24,
      x8 = 32,
      x10 = 40,
      x12 = 48;

  /// Horizontal page margin.
  static const double gutter = 24;

  /// Content never gets wider than this (tablet / web).
  static const double maxContent = 520;
}

/// Three radii only. Everything is built from these.
class AQRadius {
  AQRadius._();

  /// chips, small tags, icon tiles
  static const double small = 10;

  /// buttons, fields, choice tiles
  static const double medium = 18;

  /// sheets, large surfaces
  static const double large = 28;
}

/// Restrained, layered elevation. No ordinary control exceeds `floating`.
class AQElevation {
  AQElevation._();
  static const List<BoxShadow> none = [];
  static const List<BoxShadow> subtle = [
    BoxShadow(color: Color(0x0F2D2823), blurRadius: 6, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A2D2823), blurRadius: 16, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> modal = [
    BoxShadow(color: Color(0x262D2823), blurRadius: 28, offset: Offset(0, 10)),
  ];
}

class AQIconSize {
  AQIconSize._();
  static const double small = 18, medium = 22, large = 26, role = 28;
}

class AQControl {
  AQControl._();

  /// Minimum interactive target (WCAG / platform guidance).
  static const double tap = 48;
  static const double button = 56;
  static const double buttonCompact = 50;
  static const double field = 56;
}

/// Semantic motion. Never hard-code a Duration or Curve in a screen.
class AQMotion {
  AQMotion._();
  static const Duration micro = Duration(milliseconds: 110);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 380);

  /// Standard route push (pop uses [standard]).
  static const Duration page = Duration(milliseconds: 300);

  // Brief tokens (docs/motion). Press starts at once; release settles a little slower.
  static const Duration tapDown = Duration(milliseconds: 100);
  static const Duration tapUp = Duration(milliseconds: 160);
  static const Duration icon = Duration(milliseconds: 180);
  static const Duration sheet = Duration(milliseconds: 320);
  static const Duration sheetReverse = Duration(milliseconds: 240);
  static const Duration dialog = Duration(milliseconds: 200);
  static const Duration formStep = Duration(milliseconds: 240);
  static const Duration theme = Duration(milliseconds: 340);
  static const Duration themeReduced = Duration(milliseconds: 100);
  static const Duration state = Duration(milliseconds: 220);

  /// Horizontal travel for route and step changes, in logical pixels (mirrors in RTL).
  static const double routeTravel = 20;
  static const double stepTravel = 14;
  static const Duration hero = Duration(milliseconds: 700);
  static const Duration reveal = Duration(milliseconds: 640);

  static const Curve standardCurve = Curves.easeOutCubic;
  static const Curve decelerate = Curves.decelerate;
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Soft spring-like settle (no overshoot beyond ~3%).
  static const Curve spring = Cubic(0.22, 1.0, 0.36, 1.0);

  static bool reduced(BuildContext c) =>
      MediaQuery.maybeDisableAnimationsOf(c) ?? false;
  static Duration scaled(BuildContext c, Duration d) =>
      reduced(c) ? Duration.zero : d;
}

/// Responsive helpers: adjust, do not just scale.
class AQLayout {
  AQLayout._();
  static bool compact(BuildContext c) => MediaQuery.sizeOf(c).height < 760;
  static double contentWidth(BuildContext c) =>
      MediaQuery.sizeOf(c).width
          .clamp(0, AQSpacing.maxContent + AQSpacing.gutter * 2)
          .toDouble();

  /// 0.92..1.08 around a 393 pt reference width.
  static double scale(BuildContext c) =>
      (contentWidth(c) / 393).clamp(0.92, 1.08).toDouble();
}
