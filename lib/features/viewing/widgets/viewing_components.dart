import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/localization/viewing_strings.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/property.dart';
import '../domain/viewing_models.dart';
import '../domain/viewing_presentation.dart';
import 'viewing_format.dart';

/// Resolves a semantic tone to a foreground and a quiet tint. The only place
/// viewing colours are decided.
(Color fg, Color bg) aqToneColors(AQColors c, AQTone t) => switch (t) {
      AQTone.pending => (c.accentDeep, c.accent.withValues(alpha: c.isDark ? 0.18 : 0.14)),
      AQTone.success => (c.success, c.success.withValues(alpha: c.isDark ? 0.18 : 0.16)),
      AQTone.warning => (c.warning, c.warning.withValues(alpha: c.isDark ? 0.18 : 0.14)),
      AQTone.danger => (c.danger, c.danger.withValues(alpha: c.isDark ? 0.18 : 0.12)),
      AQTone.neutral => (c.inkSoft, c.ink.withValues(alpha: c.isDark ? 0.10 : 0.06)),
    };

/// Property photograph with a calm placeholder when none exists.
class _PropertyPhoto extends StatelessWidget {
  final Property property;
  final int cacheWidth;
  const _PropertyPhoto({required this.property, this.cacheWidth = 600});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final placeholder = ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon('home', size: AQIconSize.large, color: c.inkFaint)));
    if (property.imageUrls.isEmpty) return placeholder;
    return Semantics(
      image: true,
      label: v.t('vw.a11y.photo', {'title': property.title}),
      child: Image.asset(property.imageUrls.first, fit: BoxFit.cover, cacheWidth: cacheWidth, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => placeholder),
    );
  }
}

enum AQViewingDensity { compact, medium, large }

/// One property summary for every viewing screen; density adapts to the screen.
class AQViewingPropertySummary extends StatelessWidget {
  final Property property;
  final AQViewingDensity density;
  final String? badge;
  const AQViewingPropertySummary({super.key, required this.property, this.density = AQViewingDensity.medium, this.badge});

  String _tx(ViewingStrings v) => switch (property.transactionType) {
        TransactionType.buy => v.t('vw.tx.buy'),
        TransactionType.rent => v.t('vw.tx.rent'),
        TransactionType.lease => v.t('vw.tx.lease'),
      };

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final hero = Hero(tag: 'vw-img-${property.id}', child: _PropertyPhoto(property: property, cacheWidth: density == AQViewingDensity.large ? 1000 : 600));
    final beds = property.bedrooms;
    final facts = <(String, String)>[
      if (beds != null) ('bed', beds == 1 ? v.t('vw.bed1') : v.t('vw.beds', {'n': VFmt.n(context, beds)})),
      ('area', v.t('vw.area', {'n': VFmt.n(context, property.areaSqm.round())})),
    ];
    Widget factRow() => Wrap(spacing: AQSpacing.x4, runSpacing: AQSpacing.x1, children: [
          for (final f in facts)
            Row(mainAxisSize: MainAxisSize.min, children: [
              AQIcon(f.$1, size: 16, color: c.inkSoft),
              const SizedBox(width: AQSpacing.x1 + 2),
              Flexible(child: Text(f.$2, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
            ]),
        ]);
    Widget place() => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon('pin', size: 16, color: c.accent)),
          const SizedBox(width: AQSpacing.x1 + 2),
          Expanded(child: Text(VFmt.iso(property.locationLabel.split(',').take(2).join(',').trim()), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        ]);
    Widget badgeChip(String text) => DecoratedBox(
          decoration: BoxDecoration(color: c.isDark ? const Color(0xCC1A1613) : const Color(0xCC2D2823), borderRadius: BorderRadius.circular(AQRadius.small)),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2, vertical: 5), child: Text(text, style: AQTypography.of(context, AQText.labelMedium, color: const Color(0xFFF1E8DB)))),
        );

    switch (density) {
      case AQViewingDensity.compact:
        return AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Row(children: [
            ClipRRect(borderRadius: BorderRadius.circular(AQRadius.small + 4), child: SizedBox(width: 72, height: 72, child: hero)),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(VFmt.iso(property.title), style: AQTypography.of(context, AQText.titleSmall)),
                const SizedBox(height: AQSpacing.x1),
                place(),
              ]),
            ),
          ]),
        );
      case AQViewingDensity.medium:
        return AQSurface(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium),
            child: IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  width: aqLargeText(context) ? 92 : 128,
                  child: Stack(fit: StackFit.expand, children: [hero, if (!aqLargeText(context)) Positioned(left: AQSpacing.x2, top: AQSpacing.x2, child: badgeChip(badge ?? _tx(v)))]),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(AQSpacing.x3 + 2),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(VFmt.iso(property.title), style: AQTypography.of(context, AQText.headlineSmall)),
                      const SizedBox(height: AQSpacing.x2),
                      place(),
                      const SizedBox(height: AQSpacing.x1 + 2),
                      factRow(),
                      const SizedBox(height: AQSpacing.x2),
                      Text(property.priceLabel, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)),
                    ]),
                  ),
                ),
              ]),
            ),
          ),
        );
      case AQViewingDensity.large:
        return ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.large),
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.surface),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              AspectRatio(aspectRatio: 16 / 10, child: Stack(fit: StackFit.expand, children: [hero, Positioned(left: AQSpacing.x3, top: AQSpacing.x3, child: badgeChip(badge ?? _tx(v)))])),
              Padding(
                padding: const EdgeInsets.all(AQSpacing.x4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(VFmt.iso(property.title), style: AQTypography.of(context, AQText.headlineMedium)),
                  const SizedBox(height: AQSpacing.x2),
                  place(),
                  const SizedBox(height: AQSpacing.x2),
                  factRow(),
                  const SizedBox(height: AQSpacing.x3),
                  Text(property.priceLabel, style: AQTypography.of(context, AQText.titleLarge, color: c.accentDeep)),
                ]),
              ),
            ]),
          ),
        );
    }
  }
}

/// Icon + text status pill. Meaning never relies on colour alone.
class AQViewingStatus extends StatelessWidget {
  final ViewingPresentation presentation;
  final bool dense;
  const AQViewingStatus({super.key, required this.presentation, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final (fg, bg) = aqToneColors(c, presentation.tone);
    final label = v.t(presentation.labelKey);
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(dense ? 8 : 10, dense ? 4 : 6, dense ? 10 : 12, dense ? 4 : 6),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AQIcon(presentation.icon, size: dense ? 14 : 16, color: fg),
            const SizedBox(width: 6),
            Flexible(child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: fg))),
          ]),
        ),
      ),
    );
  }
}

/// Horizontal (or vertical at large text) progress of a viewing. Animates only when
/// the stage changes.
class AQViewingTimeline extends StatelessWidget {
  final ViewingStage current;
  final bool includeCompleted;
  const AQViewingTimeline({super.key, required this.current, this.includeCompleted = false});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final stages = [ViewingStage.requestSent, ViewingStage.underReview, ViewingStage.confirmed, ViewingStage.visit, if (includeCompleted) ViewingStage.completed];
    final names = {
      ViewingStage.requestSent: v.t('vw.stage.requestSent'),
      ViewingStage.underReview: v.t('vw.stage.underReview'),
      ViewingStage.confirmed: v.t('vw.stage.confirmed'),
      ViewingStage.visit: v.t('vw.stage.visit'),
      ViewingStage.completed: v.t('vw.stage.completed'),
    };
    final idx = stages.indexOf(current).clamp(0, stages.length - 1);
    Widget marker(int i) {
      final done = i < idx || (i == idx && current == ViewingStage.completed);
      final now = i == idx && !done;
      return AnimatedContainer(
        duration: AQMotion.scaled(context, AQMotion.standard),
        curve: AQMotion.spring,
        width: now ? 24 : 20,
        height: now ? 24 : 20,
        decoration: BoxDecoration(
          color: done || now ? c.accent : Colors.transparent,
          shape: BoxShape.circle,
          border: done || now ? null : Border.all(color: c.hairline, width: 1.5),
          boxShadow: now ? [BoxShadow(color: c.accent.withValues(alpha: 0.22), blurRadius: 8, spreadRadius: 3)] : null,
        ),
        child: done
            ? Center(child: AQIcon('check', size: 13, color: c.onAccent))
            : now
                ? Center(child: DecoratedBox(decoration: BoxDecoration(color: c.onAccent, shape: BoxShape.circle), child: const SizedBox(width: 8, height: 8)))
                : null,
      );
    }

    TextStyle label(int i) => AQTypography.of(context, i == idx ? AQText.labelMedium : AQText.bodySmall, color: i == idx ? c.ink : (i < idx ? c.inkSoft : c.inkFaint));
    final semantic = v.t('vw.timeline.step', {'n': '${idx + 1}', 'total': '${stages.length}', 'name': names[current]!});
    final body = aqLargeText(context)
        ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < stages.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1 + 1),
                child: Row(children: [SizedBox(width: 28, child: Center(child: marker(i))), const SizedBox(width: AQSpacing.x3), Expanded(child: Text(names[stages[i]]!, style: label(i)))]),
              ),
          ])
        : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < stages.length; i++)
              Expanded(
                child: Column(children: [
                  Row(children: [
                    Expanded(child: i == 0 ? const SizedBox(height: 2) : Container(height: 2, color: i <= idx ? c.accent : c.hairline)),
                    marker(i),
                    Expanded(child: i == stages.length - 1 ? const SizedBox(height: 2) : Container(height: 2, color: i < idx ? c.accent : c.hairline)),
                  ]),
                  const SizedBox(height: AQSpacing.x2),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: Text(names[stages[i]]!, textAlign: TextAlign.center, style: label(i))),
                ]),
              ),
          ]);
    return Semantics(container: true, label: v.t('vw.timeline'), value: semantic, child: ExcludeSemantics(child: body));
  }
}

/// Date, time, duration (and type) of a viewing. Three columns when there is room,
/// stacked rows otherwise, so nothing clips at large text.
class AQViewingDetailCard extends StatelessWidget {
  final ViewingSlot slot;
  final String? title;
  final AQTone tone;
  final Widget? trailing;
  final bool showType;
  const AQViewingDetailCard({super.key, required this.slot, this.title, this.tone = AQTone.neutral, this.trailing, this.showType = true});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final (fg, bg) = aqToneColors(c, tone);
    final tinted = tone != AQTone.neutral;
    Widget fact(String icon, String label, String value) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AQIcon(icon, size: AQIconSize.medium, color: tinted ? fg : c.accent),
          const SizedBox(width: AQSpacing.x2),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              const SizedBox(height: 2),
              Text(value, style: AQTypography.of(context, AQText.titleSmall)),
            ]),
          ),
        ]);
    final facts = [
      fact('calendar', v.t('vw.date'), VFmt.fullDate(context, slot.start)),
      fact('clock', v.t('vw.time'), VFmt.range(context, slot)),
      fact('user', v.t('vw.duration'), v.t('vw.minutes', {'n': VFmt.n(context, slot.minutes)})),
      if (showType) fact('pin', v.t('vw.slotType'), v.t('vw.onSite')),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(color: tinted ? Color.alphaBlend(bg, c.surfaceRaised) : c.surface, borderRadius: BorderRadius.circular(AQRadius.medium)),
      child: Padding(
        padding: const EdgeInsets.all(AQSpacing.x4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null || trailing != null) ...[
            Row(children: [
              if (title != null) Expanded(child: Semantics(header: true, child: Text(title!, style: AQTypography.of(context, AQText.headlineSmall)))) else const Spacer(),
              if (trailing != null) ...[const SizedBox(width: AQSpacing.x2), Flexible(child: trailing!)],
            ]),
            const SizedBox(height: AQSpacing.x3),
          ],
          LayoutBuilder(builder: (context, box) {
            final wide = box.maxWidth >= 300 && !aqLargeText(context);
            Widget gap() => Padding(padding: const EdgeInsets.symmetric(vertical: AQSpacing.x3), child: Divider(height: 1, thickness: 1, color: c.hairline));
            if (!wide) {
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < facts.length; i++) ...[if (i > 0) gap(), facts[i]]]);
            }
            // date, time, then duration | type: the long values keep a full row, short ones share one
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              facts[0],
              gap(),
              facts[1],
              gap(),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: facts[2]), if (showType) ...[const SizedBox(width: AQSpacing.x3), Expanded(child: facts[3])]]),
            ]);
          }),
        ]),
      ),
    );
  }
}

/// Generic calm notice (what happened / what you can do / host note).
class AQNoticeCard extends StatelessWidget {
  final String icon;
  final String title;
  final String body;
  final AQTone tone;
  const AQNoticeCard({super.key, required this.icon, required this.title, required this.body, this.tone = AQTone.neutral});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final (fg, bg) = aqToneColors(c, tone);
    return Semantics(
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: tone == AQTone.neutral ? c.surface : Color.alphaBlend(bg, c.surfaceRaised), borderRadius: BorderRadius.circular(AQRadius.medium)),
        child: Padding(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(top: 1), child: AQIcon(icon, size: AQIconSize.medium, color: tone == AQTone.neutral ? c.accent : fg)),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, body.isEmpty ? AQText.bodyMedium : AQText.titleMedium)),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: AQSpacing.x1),
                  Text(body, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Conflict-specific notice: what happened plus the choice that was lost.
class AQViewingConflictCard extends StatelessWidget {
  final ViewingSlot previous;
  const AQViewingConflictCard({super.key, required this.previous});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AQNoticeCard(icon: 'clock', tone: AQTone.warning, title: v.t('vw.conflict.what'), body: v.t('vw.conflict.body')),
      const SizedBox(height: AQSpacing.x3),
      AQSurface(
        padding: const EdgeInsets.all(AQSpacing.x4),
        child: Row(children: [
          AQIcon('calendar-x', size: AQIconSize.medium, color: c.warning),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v.t('vw.conflict.prev'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              const SizedBox(height: 2),
              Text('${VFmt.fullDate(context, previous.start)} · ${VFmt.range(context, previous)}', style: AQTypography.of(context, AQText.titleSmall).copyWith(decoration: TextDecoration.lineThrough, decorationColor: c.inkFaint)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

/// Host identity. Contact buttons appear only when real handlers exist (none wired yet).
class AQViewingHostCard extends StatelessWidget {
  final ViewingHost host;
  final bool showContactNote;
  final List<Widget> actions;
  const AQViewingHostCard({super.key, required this.host, this.showContactNote = false, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    return AQSurface(
      padding: const EdgeInsets.all(AQSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle, border: Border.all(color: c.accent.withValues(alpha: 0.5))),
            child: ExcludeSemantics(child: Text(host.initials, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep))),
          ),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(VFmt.iso(host.name), style: AQTypography.of(context, AQText.titleMedium))),
                if (host.verified) ...[const SizedBox(width: 6), AQIcon('verified', size: 18, color: c.accent)],
              ]),
              Text(host.verified ? '${v.t('vw.verifiedAgent')} · ${VFmt.iso(host.agency)}' : VFmt.iso(host.agency), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              if (host.rating != null) ...[
                const SizedBox(height: 3),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  AQIcon('star-fill', size: 14, color: c.accent),
                  const SizedBox(width: 4),
                  Flexible(child: Text('${host.rating!.toStringAsFixed(1)}${host.reviewCount != null ? ' (${v.t('vw.reviewsCount', {'n': VFmt.n(context, host.reviewCount!)})})' : ''}', style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                ]),
              ],
            ]),
          ),
          ...actions,
        ]),
        if (showContactNote) ...[
          const SizedBox(height: AQSpacing.x3),
          Text(v.t('vw.contact.note'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint)),
        ],
      ]),
    );
  }
}

/// Bounded, non-interactive map placeholder. It never pretends to be a live map:
/// real map and directions plug in here once a map SDK and launcher are connected.
class AQMapPlaceholder extends StatelessWidget {
  final double size;
  const AQMapPlaceholder({super.key, this.size = 84});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AQRadius.small + 4),
        child: SizedBox(width: size, height: size, child: CustomPaint(painter: _MapPainter(c))),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  final AQColors c;
  _MapPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    canvas.drawRect(Offset.zero & s, Paint()..color = c.surfaceSelected);
    final water = Paint()..color = c.accent.withValues(alpha: c.isDark ? 0.14 : 0.12);
    canvas.drawPath(Path()..moveTo(s.width * 0.55, 0)..quadraticBezierTo(s.width * 0.45, s.height * 0.5, s.width, s.height * 0.72)..lineTo(s.width, 0)..close(), water);
    final road = Paint()..color = c.hairline..strokeWidth = 2.2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, s.height * 0.32), Offset(s.width, s.height * 0.4), road);
    canvas.drawLine(Offset(s.width * 0.3, 0), Offset(s.width * 0.22, s.height), road);
    canvas.drawLine(Offset(0, s.height * 0.78), Offset(s.width * 0.7, s.height * 0.62), road);
    final pin = Offset(s.width * 0.5, s.height * 0.44);
    canvas.drawCircle(pin.translate(0, 9), 6, Paint()..color = const Color(0x22000000));
    final p = Path()..moveTo(pin.dx, pin.dy + 12)..cubicTo(pin.dx - 12, pin.dy, pin.dx - 10, pin.dy - 14, pin.dx, pin.dy - 14)..cubicTo(pin.dx + 10, pin.dy - 14, pin.dx + 12, pin.dy, pin.dx, pin.dy + 12);
    canvas.drawPath(p, Paint()..color = c.accent);
    canvas.drawCircle(pin.translate(0, -3), 3.2, Paint()..color = c.onAccent);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.c.brightness != c.brightness;
}

class AQViewingLocationCard extends StatelessWidget {
  final String place;
  final String note;
  const AQViewingLocationCard({super.key, required this.place, required this.note});

  @override
  Widget build(BuildContext context) {
    final v = ViewingStrings.of(context);
    return AQSurface(
      padding: const EdgeInsets.all(AQSpacing.x3),
      child: Row(children: [
        const AQMapPlaceholder(),
        const SizedBox(width: AQSpacing.x3),
        Expanded(
          child: Semantics(
            container: true,
            label: '${v.t('vw.mapPreview')}. $place. $note',
            child: ExcludeSemantics(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(VFmt.iso(place), style: AQTypography.of(context, AQText.titleMedium)),
                const SizedBox(height: AQSpacing.x1),
                Text(note, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// Quiet status moment: tone disc, a single ring, one haptic. No confetti.
class AQConfirmationState extends StatefulWidget {
  final String icon;
  final AQTone tone;
  final bool haptic;
  final double size;
  const AQConfirmationState({super.key, required this.icon, required this.tone, this.haptic = true, this.size = 104});

  @override
  State<AQConfirmationState> createState() => _AQConfirmationStateState();
}

class _AQConfirmationStateState extends State<AQConfirmationState> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: AQMotion.hero);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (AQMotion.reduced(context)) {
        _a.value = 1;
      } else {
        _a.forward();
        if (widget.haptic) AQHaptics.success();
      }
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final (fg, bg) = aqToneColors(c, widget.tone);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final disc = Curves.easeOutBack.transform(const Interval(0, 0.55).transform(_a.value).clamp(0.0, 1.0));
          final glyph = AQMotion.emphasized.transform(const Interval(0.3, 0.85).transform(_a.value).clamp(0.0, 1.0));
          final ring = Curves.easeOut.transform(const Interval(0.35, 1).transform(_a.value).clamp(0.0, 1.0));
          return SizedBox(
            width: widget.size + 28,
            height: widget.size + 28,
            child: Stack(alignment: Alignment.center, children: [
              Opacity(
                opacity: (1 - ring) * 0.9,
                child: Container(width: widget.size + 28 * ring, height: widget.size + 28 * ring, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: fg.withValues(alpha: 0.45), width: 1.5))),
              ),
              Transform.scale(
                scale: disc.clamp(0.0, 1.05),
                child: Container(width: widget.size, height: widget.size, decoration: BoxDecoration(color: Color.alphaBlend(bg, c.surfaceRaised), shape: BoxShape.circle, border: Border.all(color: fg.withValues(alpha: 0.4), width: 1.5))),
              ),
              Opacity(opacity: glyph, child: Transform.scale(scale: 0.7 + 0.3 * glyph, child: AQIcon(widget.icon, size: widget.size * 0.42, color: fg))),
            ]),
          );
        },
      ),
    );
  }
}

/// Completed viewing: invitation to review the host. Not mandatory, not a promise
/// of publication: reviews are moderated first.
class AQReviewEligibilityCard extends StatelessWidget {
  final String hostName;
  final ValueChanged<int> onRate;
  const AQReviewEligibilityCard({super.key, required this.hostName, required this.onRate});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    return AQSurface(
      padding: const EdgeInsets.all(AQSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Semantics(header: true, child: Text(v.t('vw.rate.title'), style: AQTypography.of(context, AQText.headlineSmall))),
        const SizedBox(height: AQSpacing.x1),
        Text(v.t('vw.rate.sub', {'host': hostName}), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        const SizedBox(height: AQSpacing.x2),
        Row(children: [
          for (var i = 1; i <= 5; i++)
            Semantics(
              button: true,
              focusable: true,
              onFocus: () {},
              label: v.t('vw.rate.star', {'n': VFmt.n(context, i)}),
              excludeSemantics: true,
      onTap: () {
                  AQHaptics.selection();
                  onRate(i);
                },
              child: AQPressable(
                onTap: () {
                  AQHaptics.selection();
                  onRate(i);
                },
                pressedScale: 0.9,
                child: SizedBox(width: AQControl.tap, height: AQControl.tap, child: Center(child: AQIcon('star', size: 30, color: c.accent))),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Quiet architectural arches for the empty state: editorial, not a stock illustration.
class AQArchScene extends StatelessWidget {
  final double height;
  const AQArchScene({super.key, this.height = 170});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(child: SizedBox(height: height, width: double.infinity, child: CustomPaint(painter: _ArchPainter(c))));
  }
}

class _ArchPainter extends CustomPainter {
  final AQColors c;
  _ArchPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final cx = s.width / 2;
    final base = s.height - 6;
    canvas.drawCircle(Offset(cx, s.height * 0.42), s.height * 0.34, Paint()..color = c.accent.withValues(alpha: c.isDark ? 0.16 : 0.18));
    final line = Paint()..color = c.accent.withValues(alpha: 0.8)..style = PaintingStyle.stroke..strokeWidth = 1.6..strokeCap = StrokeCap.round;
    final fill = Paint()..color = c.surface;
    void arch(double x, double w, double h) {
      final r = w / 2;
      final path = Path()..moveTo(x - r, base)..lineTo(x - r, base - h + r)..arcTo(Rect.fromCircle(center: Offset(x, base - h + r), radius: r), math.pi, math.pi, false)..lineTo(x + r, base);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, line);
    }

    arch(cx - s.width * 0.22, s.width * 0.17, s.height * 0.55);
    arch(cx + s.width * 0.22, s.width * 0.17, s.height * 0.55);
    arch(cx, s.width * 0.24, s.height * 0.78);
    canvas.drawLine(Offset(cx - s.width * 0.42, base), Offset(cx + s.width * 0.42, base), line);
  }

  @override
  bool shouldRepaint(_ArchPainter old) => old.c.brightness != c.brightness;
}

class AQEmptyViewingState extends StatelessWidget {
  final String title, body;
  final Widget? action;

  /// With an [icon] the empty state is its own kind of screen: a compact medallion in place of the
  /// shared arch scene, and optional [steps] that say what happens next.
  final String? icon;
  final List<String> steps;
  const AQEmptyViewingState({super.key, required this.title, required this.body, this.action, this.icon, this.steps = const []});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (icon == null)
        const AQArchScene()
      else
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle, border: Border.all(color: c.hairline)),
          child: Center(child: AQIcon(icon!, size: 30, color: c.accent)),
        ),
      const SizedBox(height: AQSpacing.x5),
      Semantics(header: true, child: Text(title, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.headlineLarge))),
      const SizedBox(height: AQSpacing.x2),
      Text(body, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
      if (steps.isNotEmpty) ...[
        const SizedBox(height: AQSpacing.x5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AQSpacing.x4),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: EdgeInsets.only(top: i == 0 ? 0 : AQSpacing.x3),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
                    child: Text('${i + 1}', style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep).copyWith(letterSpacing: 0)),
                  ),
                  const SizedBox(width: AQSpacing.x3),
                  Expanded(child: Text(steps[i], style: AQTypography.of(context, AQText.bodySmall))),
                ]),
              ),
          ]),
        ),
      ],
      if (action != null) ...[const SizedBox(height: AQSpacing.x6), action!],
    ]);
  }
}

/// One row of My Viewings: scan a viewing in a glance.
class AQMyViewingRow extends StatelessWidget {
  final Viewing viewing;
  final Property? property;
  final VoidCallback onTap;
  const AQMyViewingRow({super.key, required this.viewing, required this.property, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final v = ViewingStrings.of(context);
    final p = ViewingPresentation.of(viewing);
    final title = VFmt.iso(property?.title ?? v.t('vw.property'));
    final place = VFmt.iso(property?.locationLabel.split(',').first.trim() ?? '');
    final when = VFmt.dateTime(context, viewing.slot);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: v.t('vw.my.row', {'title': title, 'place': place, 'when': when, 'status': v.t(p.labelKey)}),
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AQRadius.small + 2),
              child: SizedBox(
                width: 68,
                height: 68,
                child: property == null ? ColoredBox(color: c.surfaceSelected) : _PropertyPhoto(property: property!, cacheWidth: 240),
              ),
            ),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, AQText.titleSmall)),
                if (place.isNotEmpty) Text(place, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                const SizedBox(height: AQSpacing.x1),
                Row(children: [
                  AQIcon('calendar', size: 14, color: c.inkSoft),
                  const SizedBox(width: 6),
                  Expanded(child: Text(when, style: AQTypography.of(context, AQText.bodySmall))),
                ]),
                const SizedBox(height: AQSpacing.x2),
                Align(alignment: AlignmentDirectional.centerStart, child: AQViewingStatus(presentation: p, dense: true)),
              ]),
            ),
            const SizedBox(width: AQSpacing.x1),
            AQIcon('chevron-right', size: AQIconSize.small, color: c.inkFaint, directional: true),
          ]),
        ),
      ),
    );
  }
}
