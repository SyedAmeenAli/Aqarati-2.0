import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'aq_tokens.dart';

/// The one frosted-glass material of AQARATI: floating navigation, the Shop / Work capsule, search and
/// location controls, small overlays on photographs.
///
/// A real blur of whatever is behind, a warm translucent fill, a fine light edge, a soft highlight along
/// the top and a slightly darker lower edge, so it reads as a thin sheet of material, not a faded white box.
/// With high contrast on, or when [AQGlass.opaque] is set, it becomes a solid warm surface (blur is also
/// skipped when the surface is tiny, where it would cost more than it shows).
class AQGlass extends StatelessWidget {
  final Widget child;
  final double radius;

  /// Blur sigma. 12 to 22 is the useful range; keep small overlays low.
  final double blur;

  /// 0 to 1: how much of the warm fill is present (more = calmer, easier to read on busy photographs).
  final double fill;
  final EdgeInsetsGeometry padding;
  final bool opaque;

  /// Lift: a soft layered shadow under the sheet.
  final bool shadow;
  const AQGlass({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 16,
    this.fill = 0.62,
    this.padding = EdgeInsets.zero,
    this.opaque = false,
    this.shadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final solid = opaque || MediaQuery.maybeHighContrastOf(context) == true;
    final r = BorderRadius.circular(radius);
    final base = c.isDark ? const Color(0xFF2A231D) : const Color(0xFFF7EFE4);
    final fillColor = solid ? c.surfaceRaised : base.withValues(alpha: fill.clamp(0.2, 0.95));
    final edge = (c.isDark ? Colors.white : Colors.white).withValues(alpha: c.isDark ? 0.12 : 0.55);
    // A BoxDecoration paints either its colour or its gradient, never both, so the warm fill and the
    // highlight are two layers: the fill underneath (with the edge), the soft highlight above it.
    final decorated = DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: r,
        border: Border.all(color: solid ? c.hairline : edge, width: 1),
      ),
      child: solid
          ? Padding(padding: padding, child: child)
          : DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: r,
                // A soft highlight at the top and a slightly deeper lower edge: the sheet has thickness.
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withValues(alpha: c.isDark ? 0.07 : 0.28),
                    Colors.white.withValues(alpha: 0),
                    (c.isDark ? Colors.black : const Color(0xFF674830)).withValues(alpha: c.isDark ? 0.18 : 0.06),
                  ],
                  stops: const [0, 0.5, 1],
                ),
              ),
              child: Padding(padding: padding, child: child),
            ),
    );
    final sheet = solid || blur <= 0
        ? ClipRRect(borderRadius: r, child: decorated)
        : ClipRRect(
            borderRadius: r,
            child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: decorated),
          );
    if (!shadow) return RepaintBoundary(child: sheet);
    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(color: const Color(0xFF2D2823).withValues(alpha: c.isDark ? 0.4 : 0.10), blurRadius: 18, offset: const Offset(0, 8)),
            BoxShadow(color: const Color(0xFF2D2823).withValues(alpha: c.isDark ? 0.25 : 0.06), blurRadius: 3, offset: const Offset(0, 1)),
          ],
        ),
        child: sheet,
      ),
    );
  }
}
