import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';

/// Chart colours drawn from the approved palette: bronze first, then calm neighbours.
List<Color> chartPalette(AQColors c) => [
  c.accent,
  const Color(0xFFB59A7C),
  const Color(0xFF7C8B6F),
  const Color(0xFFC08A6B),
  c.inkSoft,
];

/// A framed block with a title, a line of context and one chart. [sample] marks invented data.
class AnalyticsCard extends StatelessWidget {
  final String title;
  final String? subtitle, note;
  final Widget child;
  const AnalyticsCard({super.key, required this.title, this.subtitle, this.note, required this.child});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.titleMedium))),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(subtitle!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ),
          const SizedBox(height: AQSpacing.x3),
          child,
          if (note != null)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x2),
              child: Text(note!, style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
            ),
        ],
      ),
    );
  }
}

/// A headline figure: a large number, its label, and an optional icon. [compact] is used when three
/// tiles share one phone row.
class KpiTile extends StatelessWidget {
  final String label, value;
  final String? hint, icon;
  final VoidCallback? onTap;
  final bool compact;
  const KpiTile({super.key, required this.label, required this.value, this.hint, this.icon, this.onTap, this.compact = false});

  KpiTile asCompact() => KpiTile(label: label, value: value, hint: hint, icon: icon, onTap: onTap, compact: true);

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final pad = compact ? AQSpacing.x2 + 2 : AQSpacing.x4;
    final body = Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
        boxShadow: [BoxShadow(color: c.ink.withValues(alpha: c.isDark ? 0.0 : 0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              width: compact ? 28 : 34,
              height: compact ? 28 : 34,
              margin: const EdgeInsets.only(bottom: AQSpacing.x2),
              decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
              child: Center(child: AQIcon(icon!, size: compact ? 14 : 17, color: c.accent)),
            ),
          _KpiValue(value: value, style: AQTypography.of(context, compact ? AQText.headlineSmall : AQText.headlineLarge)),
          const SizedBox(height: 2),
          Text(label, maxLines: compact ? 3 : 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true).copyWith(fontSize: compact ? 12 : null, letterSpacing: compact ? 0 : null)),
          if (hint != null) Text(hint!, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
        ],
      ),
    );
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      button: onTap != null,
      onTap: onTap,
      child: onTap == null ? body : AQPressable(onTap: onTap, child: body),
    );
  }
}

/// A headline figure. A whole number counts up to its real value once (and again when the value
/// changes); anything else, or reduced motion, shows the value at once. The number is never invented.
class _KpiValue extends StatelessWidget {
  final String value;
  final TextStyle style;
  const _KpiValue({required this.value, required this.style});
  @override
  Widget build(BuildContext context) {
    final n = RegExp(r'^\d{1,6}$').hasMatch(value) ? int.parse(value) : null;
    if (n == null || n == 0 || AQMotion.reduced(context)) return Text(value, style: style);
    return TweenAnimationBuilder<double>(
      key: ValueKey(value),
      tween: Tween(begin: 0, end: n.toDouble()),
      duration: AQMotion.scaled(context, AQMotion.slow),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: style),
    );
  }
}

/// Tiles in balanced rows of equal height: two tiles side by side, three across (compact on a phone),
/// four as a 2 x 2 on a phone and one row on a wide screen. A tile is never left alone on its own row.
class KpiGrid extends StatelessWidget {
  final List<KpiTile> tiles;
  const KpiGrid({super.key, required this.tiles});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final n = tiles.length;
      if (n == 0) return const SizedBox.shrink();
      final large = MediaQuery.textScalerOf(context).scale(1) > 1.3;
      final wide = box.maxWidth >= 640;
      final cols = n == 1 ? 1 : (n == 2 ? 2 : (n == 3 ? (large && !wide ? 1 : 3) : (wide ? 4 : (n == 4 ? 2 : 3))));
      const gap = AQSpacing.x3;
      final w = (box.maxWidth - gap * (cols - 1)) / cols;
      final compact = cols == 3 && w < 150;
      final items = [for (final t in tiles) compact ? t.asCompact() : t];
      return Column(
        children: [
          for (var i = 0; i < items.length; i += cols) ...[
            if (i > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: gap),
                    Expanded(child: i + j < items.length ? items[i + j] : const SizedBox.shrink()),
                  ],
                ],
              ),
            ),
          ],
        ],
      );
    },
  );
}

Duration _dur(BuildContext c) => AQMotion.scaled(c, const Duration(milliseconds: 700));

/// A line chart of [values] over [labels]. The line draws in once; with reduced motion it is drawn
/// at its final state at once. Tap or drag across it to read one week: a guide line, a marker and a
/// tooltip show that week's date and value, and the same reading is available to assistive technology.
class AQLineChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String semanticsLabel;
  final double height;
  const AQLineChart({super.key, required this.values, required this.labels, required this.semanticsLabel, this.height = 190});

  @override
  State<AQLineChart> createState() => _AQLineChartState();
}

class _AQLineChartState extends State<AQLineChart> {
  int? _sel;
  static const double _left = 30, _right = 6;

  @override
  void didUpdateWidget(covariant AQLineChart old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _sel = null;
  }

  void _pick(Offset p, double width, bool rtl) {
    final n = widget.values.length;
    if (n == 0) return;
    final w = width - _left - _right;
    final x = rtl ? (width - p.dx) - _right : p.dx - _left;
    final i = n == 1 ? 0 : (x / w * (n - 1)).round().clamp(0, n - 1);
    if (i != _sel) setState(() => _sel = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final style = AQTypography.of(context, AQText.labelSmall, color: c.inkFaint);
    final tip = AQTypography.of(context, AQText.labelMedium, color: c.surfaceRaised);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sel = _sel;
    return Semantics(
      label: widget.semanticsLabel + (sel == null ? '' : '. ${widget.labels[sel]}: ${widget.values[sel].round()}'),
      image: true,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(widget.values.join(',')),
          tween: Tween(begin: 0, end: 1),
          duration: _dur(context),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              onHorizontalDragStart: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _LinePainter(widget.values, widget.labels, t, c.accent, c.hairline, style, rtl, sel, tip, c.ink, c.surfaceRaised),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double t;
  final Color line, grid, tipBg, surface;
  final TextStyle style, tipStyle;
  final bool rtl;
  final int? selected;
  _LinePainter(this.values, this.labels, this.t, this.line, this.grid, this.style, this.rtl, this.selected, this.tipStyle, this.tipBg, this.surface);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 30.0, bottom = 22.0, top = 10.0;
    final w = size.width - left - 6, h = size.height - bottom - top;
    final maxV = math.max(values.reduce(math.max), 1.0);
    final top4 = _niceMax(maxV).roundToDouble();
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    // Whole-number gridlines: the scale is split into the number of equal steps that divides it evenly.
    final steps = [4, 5, 3, 2, 1].firstWhere((k) => top4 % k == 0, orElse: () => 1);
    for (var i = 0; i <= steps; i++) {
      final y = top + h - h * i / steps;
      canvas.drawLine(Offset(left, y), Offset(size.width - 6, y), gridPaint);
      _text(canvas, (top4 * i / steps).round().toString(), Offset(0, y - 7), style, 26, TextAlign.right);
    }
    Offset pt(int i) {
      final x = values.length == 1 ? left + w / 2 : left + w * i / (values.length - 1);
      final px = rtl ? size.width - x + left - 6 : x;
      return Offset(px, top + h - h * (values[i] / top4));
    }
    // Straight segments between the real points: nothing is smoothed, so the line never shows a value that is not there.
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final metrics = path.computeMetrics().toList();
    final drawn = Path();
    for (final m in metrics) {
      drawn.addPath(m.extractPath(0, m.length * t), Offset.zero);
    }
    canvas.drawPath(drawn, Paint()..color = line..style = PaintingStyle.stroke..strokeWidth = 2..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
    for (var i = 0; i < values.length; i++) {
      if (t >= 0.98) canvas.drawCircle(pt(i), 2.6, Paint()..color = line);
    }
    final step = math.max(1, (labels.length / 6).ceil());
    for (var i = 0; i < labels.length; i += step) {
      _text(canvas, labels[i], Offset(pt(i).dx - 20, size.height - 16), style, 40, TextAlign.center);
    }
    // The marker: the selected week, otherwise the latest.
    final mi = selected ?? values.length - 1;
    if (t >= 0.98) {
      final m = pt(mi);
      if (selected != null) {
        canvas.drawLine(Offset(m.dx, top), Offset(m.dx, top + h), Paint()..color = line.withValues(alpha: 0.45)..strokeWidth = 1.2);
      }
      canvas.drawCircle(m, 7, Paint()..color = line.withValues(alpha: 0.18));
      canvas.drawCircle(m, 4.5, Paint()..color = surface);
      canvas.drawCircle(m, 3.2, Paint()..color = line);
      if (selected != null) {
        final tp = TextPainter(text: TextSpan(text: '${labels[mi]}  ·  ${values[mi].round()}', style: tipStyle), textDirection: TextDirection.ltr)..layout();
        final bw = tp.width + 20, bh = tp.height + 12;
        var bx = m.dx - bw / 2;
        bx = bx.clamp(left - 4, size.width - bw - 2);
        final by = (m.dy - bh - 12) < 0 ? m.dy + 12 : m.dy - bh - 12;
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(10)), Paint()..color = tipBg);
        tp.paint(canvas, Offset(bx + 10, by + 6));
      }
    }
  }

  double _niceMax(double v) {
    final base = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 4, 5, 8, 10]) {
      if (v <= m * base) return (m * base).roundToDouble();
    }
    return v;
  }

  void _text(Canvas canvas, String s, Offset o, TextStyle st, double width, TextAlign a) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, textAlign: a)..layout(minWidth: width, maxWidth: width + 24);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.t != t || old.values != values || old.selected != selected || old.line != line;
}

/// Horizontal bars for comparable categories.
class AQBarChart extends StatelessWidget {
  final List<(String, double)> items;
  const AQBarChart({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final maxV = math.max(items.fold<double>(0, (m, e) => math.max(m, e.$2)), 1.0);
    return Semantics(
      label: [for (final e in items) '${e.$1}: ${e.$2.round()}'].join(', '),
      image: true,
      child: ExcludeSemantics(
        child: Column(
          children: [
            for (final (i, e) in items.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(width: 108, child: Text(e.$1, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall))),
                    Expanded(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('${e.$1}${e.$2}'),
                        tween: Tween(begin: 0, end: e.$2 / maxV),
                        duration: AQMotion.scaled(context, Duration(milliseconds: 500 + i * 60)),
                        curve: Curves.easeOutCubic,
                        builder: (context, v, _) => ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(value: v, minHeight: 10, color: chartPalette(c)[i % 5], backgroundColor: c.hairline),
                        ),
                      ),
                    ),
                    SizedBox(width: 36, child: Text('${e.$2.round()}', textAlign: TextAlign.end, style: AQTypography.of(context, AQText.labelMedium))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A donut for a composition that sums to a whole, with its legend.
class AQDonut extends StatelessWidget {
  final List<(String, double)> parts;
  final String centerLabel;
  const AQDonut({super.key, required this.parts, required this.centerLabel});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final colors = chartPalette(c);
    final total = parts.fold<double>(0, (s, e) => s + e.$2);
    return Semantics(
      label: [for (final e in parts) '${e.$1}: ${e.$2.round()}'].join(', '),
      image: true,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, box) {
            final stacked = box.maxWidth < 360;
            final ring = SizedBox(
              width: 132,
              height: 132,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(parts.map((e) => e.$2).join(',')),
                tween: Tween(begin: 0, end: 1),
                duration: _dur(context),
                curve: Curves.easeOutCubic,
                builder: (context, t, _) => CustomPaint(
                  painter: _DonutPainter([for (final (i, e) in parts.indexed) (e.$2, colors[i % colors.length])], total, t, c.hairline),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${total.round()}', style: AQTypography.of(context, AQText.headlineSmall)),
                        Text(centerLabel, style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
                      ],
                    ),
                  ),
                ),
              ),
            );
            final legend = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final (i, e) in parts.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[i % colors.length], borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 8),
                        Flexible(child: Text('${e.$1}  ${e.$2.round()}', style: AQTypography.of(context, AQText.bodySmall))),
                      ],
                    ),
                  ),
              ],
            );
            return stacked
                ? Column(children: [ring, const SizedBox(height: AQSpacing.x3), Align(alignment: AlignmentDirectional.centerStart, child: legend)])
                : Row(children: [ring, const SizedBox(width: AQSpacing.x5), Expanded(child: legend)]);
          },
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<(double, Color)> parts;
  final double total, t;
  final Color track;
  _DonutPainter(this.parts, this.total, this.t, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromCircle(center: size.center(Offset.zero), radius: size.shortestSide / 2 - 9);
    final base = Paint()..style = PaintingStyle.stroke..strokeWidth = 16..color = track;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (final p in parts) {
      final sweep = math.pi * 2 * (p.$1 / total) * t;
      if (sweep > 0.01) {
        canvas.drawArc(r, start, math.max(sweep - 0.03, 0.01), false, Paint()..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.butt..color = p.$2);
      }
      start += math.pi * 2 * (p.$1 / total) * t;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => old.t != t || old.total != total;
}

/// Weekly counts as vertical bars: one bar per real value, a labelled scale, and a reading for one week on
/// tap or drag (date and value, kept inside the chart's edges). Bars start at zero and are never smoothed.
class AQColumnChart extends StatefulWidget {
  final List<double> values;
  final List<String> labels;
  final String semanticsLabel;
  final double height;
  const AQColumnChart({super.key, required this.values, required this.labels, required this.semanticsLabel, this.height = 190});
  @override
  State<AQColumnChart> createState() => _AQColumnChartState();
}

class _AQColumnChartState extends State<AQColumnChart> {
  int? _sel;
  static const double _left = 30, _right = 4;

  @override
  void didUpdateWidget(covariant AQColumnChart old) {
    super.didUpdateWidget(old);
    if (old.values.length != widget.values.length) _sel = null;
  }

  void _pick(Offset p, double width, bool rtl) {
    final n = widget.values.length;
    if (n == 0) return;
    final w = width - _left - _right;
    final x = rtl ? (width - p.dx) - _right : p.dx - _left;
    final i = (x / w * n).floor().clamp(0, n - 1);
    if (i != _sel) setState(() => _sel = i);
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final sel = _sel;
    return Semantics(
      label: widget.semanticsLabel + (sel == null ? '' : '. ${widget.labels[sel]}: ${widget.values[sel].round()}'),
      image: true,
      child: ExcludeSemantics(
        child: TweenAnimationBuilder<double>(
          key: ValueKey(widget.values.join(',')),
          tween: Tween(begin: 0, end: 1),
          duration: _dur(context),
          curve: Curves.easeOutCubic,
          builder: (context, t, _) => LayoutBuilder(
            builder: (context, box) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              onHorizontalDragStart: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              onHorizontalDragUpdate: (d) => _pick(d.localPosition, box.maxWidth, rtl),
              child: SizedBox(
                height: widget.height,
                width: double.infinity,
                child: CustomPaint(
                  painter: _ColumnPainter(widget.values, widget.labels, t, c.accent, c.hairline, AQTypography.of(context, AQText.labelSmall, color: c.inkFaint), AQTypography.of(context, AQText.labelMedium, color: c.surfaceRaised), c.ink, rtl, sel),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double t;
  final Color bar, grid, tipBg;
  final TextStyle style, tipStyle;
  final bool rtl;
  final int? selected;
  _ColumnPainter(this.values, this.labels, this.t, this.bar, this.grid, this.style, this.tipStyle, this.tipBg, this.rtl, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const left = 30.0, right = 4.0, bottom = 22.0, top = 10.0;
    final w = size.width - left - right, h = size.height - bottom - top;
    final maxV = math.max(values.reduce(math.max), 1.0);
    final base = math.pow(10, (math.log(maxV) / math.ln10).floor()).toDouble();
    var topV = maxV;
    for (final m in [1, 2, 4, 5, 8, 10]) {
      if (maxV <= m * base) {
        topV = (m * base).roundToDouble();
        break;
      }
    }
    final steps = [4, 5, 3, 2, 1].firstWhere((k) => topV % k == 0, orElse: () => 1);
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    for (var i = 0; i <= steps; i++) {
      final y = top + h - h * i / steps;
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);
      _text(canvas, (topV * i / steps).round().toString(), Offset(0, y - 7), style, 26, TextAlign.right);
    }
    final slot = w / values.length;
    final bw = math.min(slot * 0.62, 26.0);
    double cx(int i) {
      final x = left + slot * i + slot / 2;
      return rtl ? size.width - x + left - right + 0 : x;
    }
    for (var i = 0; i < values.length; i++) {
      final hh = h * (values[i] / topV) * t;
      final r = RRect.fromRectAndCorners(Rect.fromLTWH(cx(i) - bw / 2, top + h - hh, bw, hh), topLeft: const Radius.circular(3), topRight: const Radius.circular(3));
      canvas.drawRRect(r, Paint()..color = (selected == null || selected == i) ? bar : bar.withValues(alpha: 0.35));
    }
    final step = math.max(1, (labels.length / 6).ceil());
    for (var i = 0; i < labels.length; i += step) {
      _text(canvas, labels[i], Offset(cx(i) - 20, size.height - 16), style, 40, TextAlign.center);
    }
    final si = selected;
    if (si != null && t >= 0.98) {
      final tp = TextPainter(text: TextSpan(text: '${labels[si]}  ·  ${values[si].round()}', style: tipStyle), textDirection: TextDirection.ltr)..layout();
      final bwid = tp.width + 20, bh = tp.height + 12;
      final topY = top + h - h * (values[si] / topV);
      var bx = cx(si) - bwid / 2;
      bx = bx.clamp(left - 4, size.width - bwid - 2);
      final by = (topY - bh - 8) < 0 ? topY + 6 : topY - bh - 8;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bwid, bh), const Radius.circular(10)), Paint()..color = tipBg);
      tp.paint(canvas, Offset(bx + 10, by + 6));
    }
  }

  void _text(Canvas canvas, String s, Offset o, TextStyle st, double width, TextAlign a) {
    final tp = TextPainter(text: TextSpan(text: s, style: st), textDirection: TextDirection.ltr, textAlign: a)..layout(minWidth: width, maxWidth: width + 24);
    tp.paint(canvas, o);
  }

  @override
  bool shouldRepaint(covariant _ColumnPainter old) => old.t != t || old.values != values || old.selected != selected || old.bar != bar;
}
