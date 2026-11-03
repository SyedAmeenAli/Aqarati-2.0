import 'package:flutter/material.dart';

import '../domain/account_models.dart';
import '../localization/flow_strings.dart';
import 'aq_primitives.dart';
import 'aq_tokens.dart';
import 'aq_typography.dart';

/// One status vocabulary for role grants. Wording follows the state names exactly;
/// developer "awaiting second approval" is its own badge.
class AQStatusBadge extends StatelessWidget {
  final GrantState grant;
  final ReviewStage? stage;
  const AQStatusBadge({super.key, required this.grant, this.stage});

  static String labelKey(GrantState g, ReviewStage? stage) {
    if (g == GrantState.pendingVerification &&
        stage == ReviewStage.awaitingSecondApproval)
      return 'badge.awaitingSecond';
    return switch (g) {
      GrantState.draft => 'badge.draft',
      GrantState.pendingVerification => 'badge.pendingVerification',
      GrantState.approved => 'badge.approved',
      GrantState.resubmissionRequired => 'badge.resubmissionRequired',
      GrantState.rejected => 'badge.rejected',
      GrantState.suspended => 'badge.suspended',
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final (fg, icon) = switch (grant) {
      GrantState.approved => (c.success, 'shield'),
      GrantState.pendingVerification => (c.accentDeep, 'activity'),
      GrantState.resubmissionRequired => (c.danger, 'alert'),
      GrantState.rejected => (c.danger, 'close'),
      GrantState.suspended => (c.inkSoft, 'lock'),
      GrantState.draft => (c.inkSoft, 'info'),
    };
    return Semantics(
      label: f.t(labelKey(grant, stage)),
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AQSpacing.x3,
          vertical: AQSpacing.x2,
        ),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AQRadius.small + 8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AQIcon(icon, size: AQIconSize.small, color: fg),
            const SizedBox(width: AQSpacing.x2),
            Text(
              f.t(labelKey(grant, stage)),
              style: AQTypography.of(context, AQText.labelMedium, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

class AQTimelineStep {
  final String label;
  final String? detail;
  const AQTimelineStep(this.label, [this.detail]);
}

/// Vertical timeline. Done steps are quiet, the current step is dominant (and softly
/// "breathes"), upcoming steps are faint. Never spins.
class AQVerificationTimeline extends StatefulWidget {
  final List<AQTimelineStep> steps;

  /// Index of the current step. Steps before it are done.
  final int current;
  const AQVerificationTimeline({
    super.key,
    required this.steps,
    required this.current,
  });

  @override
  State<AQVerificationTimeline> createState() => _AQVerificationTimelineState();
}

class _AQVerificationTimelineState extends State<AQVerificationTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AQMotion.reduced(context)) {
      _breathe.stop();
    } else if (!_breathe.isAnimating) {
      _breathe.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Column(
      children: [
        for (var i = 0; i < widget.steps.length; i++)
          Semantics(
            container: true,
            label:
                '${widget.steps[i].label}${i < widget.current
                    ? ', done'
                    : i == widget.current
                    ? ', current'
                    : ''}',
            excludeSemantics: true,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 28,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        _dot(c, i),
                        if (i < widget.steps.length - 1)
                          Expanded(
                            child: Container(
                              width: 2,
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: i < widget.current ? c.accent : c.hairline,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AQSpacing.x3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.steps[i].label,
                            style: AQTypography.of(
                              context,
                              i == widget.current
                                  ? AQText.titleMedium
                                  : AQText.bodyMedium,
                              color: i > widget.current ? c.inkFaint : c.ink,
                            ),
                          ),
                          if (widget.steps[i].detail != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                widget.steps[i].detail!,
                                style: AQTypography.of(
                                  context,
                                  AQText.bodySmall,
                                  soft: true,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _dot(AQColors c, int i) {
    if (i < widget.current) {
      return Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
        child: Center(child: AQIcon('check', size: 12, color: c.onAccent)),
      );
    }
    if (i == widget.current) {
      return AnimatedBuilder(
        animation: _breathe,
        builder: (context, _) => SizedBox(
          width: 18,
          height: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.accent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: c.accent.withValues(
                    alpha: 0.12 + 0.2 * _breathe.value,
                  ),
                  blurRadius: 3 + 8 * _breathe.value,
                  spreadRadius: 1 + 4 * _breathe.value,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: c.hairline, width: 1.5),
      ),
    );
  }
}

/// Titled block for review/details: heading, optional Edit, then rows.
class AQReviewSection extends StatelessWidget {
  final String title;
  final String? editLabel;
  final VoidCallback? onEdit;
  final List<Widget> children;
  const AQReviewSection({
    super.key,
    required this.title,
    this.editLabel,
    this.onEdit,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
      child: AQSurface(
        padding: const EdgeInsets.fromLTRB(
          AQSpacing.x4,
          AQSpacing.x3,
          AQSpacing.x4,
          AQSpacing.x3,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AQTypography.of(context, AQText.titleMedium),
                    ),
                  ),
                ),
                if (onEdit != null && editLabel != null)
                  AQTextButton(
                    label: editLabel!,
                    color: AQColors.of(context).accent,
                    onPressed: onEdit,
                  ),
              ],
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class AQKeyValue extends StatelessWidget {
  final String label, value;
  const AQKeyValue(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AQTypography.of(context, AQText.bodySmall, soft: true),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: AQTypography.of(context, AQText.titleSmall),
          ),
        ),
      ],
    ),
  );
}

/// Compact read-only document row with status and expiry awareness.
class AQDocumentRow extends StatelessWidget {
  final String title;
  final DocumentStatus status;

  /// Optional: tap the row to open the document preview.
  final VoidCallback? onTap;
  const AQDocumentRow({
    super.key,
    required this.title,
    required this.status,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final visual = aqDocVisual(docDisplayOfStatus(status));
    final text = f.t(visual.key);
    final color = aqDocToneColor(c, visual.tone);
    final icon = visual.icon;
    final ex = expiryStatusOf(status.expiry);
    final loc = MaterialLocalizations.of(context);
    final meta = <String>[
      if (status.fileName != null) status.fileName!,
      if (status.sizeBytes != null) '${(status.sizeBytes! / 1024).round()} KB',
    ].join(' · ');
    final expiryLine = status.expiry == null
        ? null
        : switch (ex) {
            ExpiryStatus.expired => f.t('expiry.expired', {
              'd': loc.formatMediumDate(status.expiry!),
            }),
            ExpiryStatus.expiringSoon => f.t('expiry.soon', {
              'd': loc.formatMediumDate(status.expiry!),
            }),
            _ => f.t('ver.expires', {
              'd': loc.formatMediumDate(status.expiry!),
            }),
          };
    return Semantics(
      container: true,
      button: onTap != null,
      label: '$title: $text${expiryLine == null ? '' : ', $expiryLine'}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: onTap,
        pressedScale: 0.995,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: AQIcon(icon, size: AQIconSize.medium, color: color),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    Text(
                      text,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        color: color,
                      ),
                    ),
                    if (meta.isNotEmpty)
                      Text(
                        meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          color: c.inkFaint,
                        ),
                      ),
                    if (expiryLine != null)
                      Text(
                        expiryLine,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          color: ex == ExpiryStatus.expired
                              ? c.danger
                              : (ex == ExpiryStatus.expiringSoon
                                    ? c.accentDeep
                                    : c.inkSoft),
                        ),
                      ),
                  ],
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: AQIcon(
                    'chevron-right',
                    size: AQIconSize.small,
                    directional: true,
                    color: c.inkFaint,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Display vocabulary for one document: text key, icon and tone. Icon + text always, never colour alone.
enum AQDocTone { quiet, neutral, good, attention }

({String key, String icon, AQDocTone tone}) aqDocVisual(DocDisplay d) =>
    switch (d) {
      DocDisplay.empty => (
        key: 'docs.state.idle',
        icon: 'info',
        tone: AQDocTone.quiet,
      ),
      DocDisplay.uploading => (
        key: 'docs.state.uploading',
        icon: 'refresh',
        tone: AQDocTone.quiet,
      ),
      DocDisplay.processing => (
        key: 'docs.state.processing',
        icon: 'refresh',
        tone: AQDocTone.quiet,
      ),
      DocDisplay.underReview => (
        key: 'docs.state.review',
        icon: 'clock',
        tone: AQDocTone.neutral,
      ),
      DocDisplay.verified => (
        key: 'docs.state.accepted',
        icon: 'check',
        tone: AQDocTone.good,
      ),
      DocDisplay.needsUpdate => (
        key: 'docs.state.rejected',
        icon: 'alert',
        tone: AQDocTone.attention,
      ),
      DocDisplay.expired => (
        key: 'docs.state.expired',
        icon: 'alert',
        tone: AQDocTone.attention,
      ),
      DocDisplay.missing => (
        key: 'docs.state.missing',
        icon: 'info',
        tone: AQDocTone.quiet,
      ),
      DocDisplay.failed => (
        key: 'docs.state.failed',
        icon: 'alert',
        tone: AQDocTone.attention,
      ),
    };

Color aqDocToneColor(AQColors c, AQDocTone t) => switch (t) {
  AQDocTone.quiet => c.inkSoft,
  AQDocTone.neutral => c.accentDeep,
  AQDocTone.good => c.success,
  AQDocTone.attention => c.danger,
};
