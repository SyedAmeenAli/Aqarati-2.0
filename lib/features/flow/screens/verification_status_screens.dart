import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_documents.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/config/backend_mode.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../../data/demo/demo_backend.dart';
import '../state/document_state.dart';
import '../widgets/document_preview.dart';
import '../widgets/document_upload_tile.dart';
import '../widgets/journey.dart';
import '../widgets/flow_common.dart';

String _reasonText(FlowStrings f, String? code) {
  if (code == null) return f.t('reason.unknown');
  final key = 'reason.$code';
  return FlowStrings.keys.contains(key) ? f.t(key) : f.t('reason.unknown');
}

/// Documents the user chose to replace in the current resubmission (so the review
/// can separate "Updated" from "Already approved"). Metadata only.
final resubmissionTargetsProvider = StateProvider<Set<DocumentKind>>((ref) => <DocumentKind>{});
final lastResubmittedProvider = StateProvider<({Set<DocumentKind> changed, DateTime at})?>((ref) => null);

/// Customer verification status: state, dominant current stage, what is missing,
/// what needs correction, and the next action. Nothing is invented.
class VerificationStatusScreen extends ConsumerWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('ver.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('ver.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        // Buyers have no application to verify; never show them a business-style status.
        if (!(roleConfigs[info.purpose]?.needsDocuments ?? false)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/app/home');
          });
          return const SizedBox.shrink();
        }
        return _Status(info: info);
      },
    );
  }
}

class _Status extends ConsumerWidget {
  final VerificationInfo info;
  const _Status({required this.info});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final loc = MaterialLocalizations.of(context);
    final cfg = roleConfigs[info.purpose]!;
    final missing = info.documents.where((d) => d.outcome == DocumentOutcome.notSubmitted).toList();
    final fix = info.documents.where((d) => d.outcome == DocumentOutcome.rejected).toList();
    // "Awaiting second approval" only exists for the four-eyes (developer) path.
    final second = info.stage == ReviewStage.awaitingSecondApproval && cfg.fourEyes;

    final (headKey, bodyKey) = switch (info.grant) {
      GrantState.draft => ('vh.draft', 'ver.body.draft'),
      GrantState.pendingVerification => second ? ('vh.second', 'ver.body.second') : ('vh.pending', 'ver.body.pending'),
      GrantState.approved => ('vh.approved', 'ver.body.approved'),
      GrantState.resubmissionRequired => ('vh.resub', 'ver.body.resubmission'),
      GrantState.rejected => ('vh.rejected', 'ver.body.rejected'),
      GrantState.suspended => ('vh.suspended', 'ver.body.suspended'),
    };
    final (String, String)? action = switch (info.grant) {
      GrantState.draft => (f.t('ver.action.docs'), '/onboarding/documents'),
      GrantState.resubmissionRequired => (f.t('ver.action.fix'), '/verification/resubmit'),
      GrantState.approved => (f.t('ver.action.continue'), '/verification/approved'),
      _ => null,
    };

    final steps = [
      AQTimelineStep(f.t('tl.submitted'), info.submittedAt == null ? null : loc.formatMediumDate(info.submittedAt!)),
      AQTimelineStep(f.t('tl.review')),
      if (cfg.fourEyes) AQTimelineStep(f.t('tl.second')),
      AQTimelineStep(f.t('tl.approved')),
    ];
    final current = info.grant == GrantState.approved ? steps.length - 1 : (second ? 2 : 1);
    final showTimeline = info.grant == GrantState.pendingVerification || info.grant == GrantState.approved;

    return AQAuthScaffold(
      showLogo: false,
      title: f.t(headKey),
      subtitle: f.t(bodyKey),
      // Root of the authenticated onboarding area: Back would only lead to Welcome.
      showBack: false,
      progress: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        journeyProgress(context, info.purpose, JourneyAt.status),
        const SizedBox(height: AQSpacing.x3),
        AQStatusBadge(grant: info.grant, stage: second ? info.stage : null),
      ]),
      bottom: Column(mainAxisSize: MainAxisSize.min, children: [
        if (action != null) AQPrimaryButton(label: action.$1, onPressed: () => context.go(action.$2)) else AQSecondaryButton(label: f.t('ver.action.refresh'), trailingChevron: false, onPressed: () => ref.invalidate(verificationProvider)),
        AQTextButton(label: f.t('ver.viewApplication'), onPressed: () => context.go('/verification/details')),
      ]),
      children: [
        if (info.grant == GrantState.pendingVerification) AQReviewSection(title: f.t('ver.yourAction'), children: [Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('ver.nothingNeeded'), style: AQTypography.of(context, AQText.titleSmall, color: c.accentDeep)))]),
        if (showTimeline) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: AQVerificationTimeline(steps: steps, current: current)),
        if (info.grant == GrantState.approved && info.decidedAt != null) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: Text(f.t('ver.decided', {'d': loc.formatMediumDate(info.decidedAt!)}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
        AQReviewSection(title: f.t('ver.documents'), children: [for (final d in info.documents) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d, onTap: d.fileName == null ? null : () => showDocumentPreview(context, d.kind, status: d))]),
        if (missing.isNotEmpty && info.grant != GrantState.approved) AQErrorBanner(tone: AQBannerTone.info, text: '${f.t('ver.missing')}: ${missing.map((d) => f.t(documentLabelKey(d.kind))).join(', ')}'),
        if (fix.isNotEmpty) AQErrorBanner(text: '${f.t('ver.correction')}: ${fix.map((d) => f.t(documentLabelKey(d.kind))).join(', ')}\n${f.t('ver.reason')}: ${_reasonText(f, fix.first.rejectionReasonCode ?? info.reasonCode)}'),
        if (info.grant == GrantState.rejected) AQErrorBanner(text: '${f.t('ver.reason')}: ${_reasonText(f, info.reasonCode)}${info.decidedAt == null ? '' : '\n${f.t('ver.decided', {'d': loc.formatMediumDate(info.decidedAt!)})}'}'),
        if (kShowReviewTools) const _DemoControls(),
      ],
    );
  }
}

/// Read-only application record. Explains when editing is not possible.
class ApplicationDetailsScreen extends ConsumerWidget {
  const ApplicationDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final loc = MaterialLocalizations.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('det.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('det.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        final reviewer = info.grant == GrantState.resubmissionRequired || info.grant == GrantState.rejected;
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('det.title'),
          onBack: () => context.go('/verification'),
          backLabel: f.t('common.back'),
          bottom: info.grant == GrantState.resubmissionRequired ? AQPrimaryButton(label: f.t('ver.action.fix'), onPressed: () => context.go('/verification/resubmit')) : null,
          children: [
            AQReviewSection(title: f.t('det.title'), children: [
              AQKeyValue(f.t('det.reference'), info.reference ?? f.t('det.refPending')),
              AQKeyValue(f.t('det.submittedAt'), info.submittedAt == null ? f.t('ver.notSubmitted') : '${loc.formatMediumDate(info.submittedAt!)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(info.submittedAt!))}'),
              AQKeyValue(f.t('det.type'), roleTitle(context, info.purpose)),
              if (info.businessName != null) AQKeyValue(f.t('det.company'), info.businessName!),
              AQKeyValue(f.t('det.status'), f.t(AQStatusBadge.labelKey(info.grant, info.stage))),
            ]),
            AQReviewSection(title: f.t('ver.documents'), children: [for (final d in info.documents) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d, onTap: d.fileName == null ? null : () => showDocumentPreview(context, d.kind, status: d))]),
            if (reviewer) AQErrorBanner(text: '${f.t('ver.reason')}: ${_reasonText(f, info.reasonCode)}'),
            if (info.grant == GrantState.pendingVerification) AQErrorBanner(tone: AQBannerTone.info, text: f.t('det.locked')),
          ],
        );
      },
    );
  }
}

/// Only affected documents are replaced; everything else stays as submitted.
Map<DocumentKind, DocumentStatus> byKindPre(VerificationInfo info) => {for (final d in info.documents) d.kind: d};

/// A target is resolved once its tile shows the document as received (under review) or verified.
bool _resolved(DocumentState s) => s.display == DocDisplay.underReview || s.display == DocDisplay.verified;

class ResubmissionScreen extends ConsumerWidget {
  const ResubmissionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('resub.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('resub.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        var targets = ref.watch(resubmissionTargetsProvider);
        if (targets.isEmpty) {
          final found = resubmissionTargetsOf(info.documents);
          if (found.isNotEmpty) {
            Future.microtask(() => ref.read(resubmissionTargetsProvider.notifier).state = found);
            targets = found;
          }
        }
        if (targets.isEmpty) {
          return AQAuthScaffold(
            showLogo: false,
            title: f.t('resub.title'),
            subtitle: f.t('resub.none'),
            onBack: () => context.go('/verification'),
            bottom: AQPrimaryButton(label: f.t('ver.title'), onPressed: () => context.go('/verification')),
            children: const [],
          );
        }
        final allDone = targets.every((k) => _resolved(ref.watch(documentControllerProvider(k))));
        final anyBusy = targets.any((k) => ref.watch(documentControllerProvider(k)).busy);
        final anyFix = targets.any((k) => byKindPre(info)[k]?.outcome == DocumentOutcome.rejected);
        final byKind = {for (final d in info.documents) d.kind: d};
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('resub.title'),
          subtitle: f.t('resub.sub'),
          onBack: () => context.go('/verification'),
          backLabel: f.t('common.back'),
          bottom: AQPrimaryButton(label: f.t('resub.reviewCta'), onPressed: allDone && !anyBusy ? () => context.go('/verification/resubmit/review') : null),
          children: [
            if (anyFix) AQErrorBanner(text: '${f.t('resub.why')}: ${_reasonText(f, info.reasonCode ?? byKind[targets.first]?.rejectionReasonCode)}'),
            for (final k in targets)
              DocumentUploadTile(key: ValueKey(k), kind: k, seed: initialFromStatus(byKind[k]), rejectionReason: _reasonText(f, byKind[k]?.rejectionReasonCode ?? info.reasonCode)),
            for (final d in info.documents.where((d) => !targets.contains(d.kind)))
              Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x1), child: AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d, onTap: d.fileName == null ? null : () => showDocumentPreview(context, d.kind, status: d))),
          ],
        );
      },
    );
  }
}

/// Explicit confirmation: Updated vs Already approved.
class ResubmitReviewScreen extends ConsumerStatefulWidget {
  const ResubmitReviewScreen({super.key});
  @override
  ConsumerState<ResubmitReviewScreen> createState() => _ResubmitReviewScreenState();
}

class _ResubmitReviewScreenState extends ConsumerState<ResubmitReviewScreen> {
  bool _busy = false;
  String? _bannerKey;

  Future<void> _confirm(Set<DocumentKind> changed) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _bannerKey = null;
    });
    try {
      await ref.read(accountApiProvider).resubmit();
      ref.read(lastResubmittedProvider.notifier).state = (changed: changed, at: DateTime.now());
      ref.read(resubmissionTargetsProvider.notifier).state = <DocumentKind>{};
      ref.invalidate(verificationProvider);
      AQHaptics.success();
      if (mounted) context.go('/verification/resubmitted');
    } catch (e) {
      if (mounted) setState(() => _bannerKey = apiErrorKey(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final targets = ref.watch(resubmissionTargetsProvider);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('rr.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('rr.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        // Only a document the model reports as accepted is "already approved"; pending ones stay pending.
        final g = groupForReview(info.documents, targets);
        final updated = g.updated, approved = g.approved, pending = g.pending, stillNeeds = g.stillNeeds;
        final canConfirm = targets.isNotEmpty ? targets.every((k) => _resolved(ref.watch(documentControllerProvider(k)))) : stillNeeds.isEmpty;
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('rr.title'),
          subtitle: f.t('rr.sub'),
          onBack: () => context.go('/verification/resubmit'),
          backLabel: f.t('common.back'),
          bottom: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_bannerKey != null) AQErrorBanner(text: f.t(_bannerKey!)),
            AQPrimaryButton(label: f.t('rr.confirm'), loading: _busy, onPressed: canConfirm ? () => _confirm(targets) : null),
          ]),
          children: [
            AQReviewSection(title: f.t('rr.updated'), editLabel: f.t('review.edit'), onEdit: () => context.go('/verification/resubmit'), children: updated.isEmpty ? [Text(f.t('rr.nothing'), style: AQTypography.of(context, AQText.bodySmall, soft: true))] : [for (final d in updated) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d)]),
            if (approved.isNotEmpty) AQReviewSection(title: f.t('rr.approved'), children: [for (final d in approved) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d)]),
            if (pending.isNotEmpty) AQReviewSection(title: f.t('rr.pending'), children: [for (final d in pending) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d)]),
            if (stillNeeds.isNotEmpty) AQErrorBanner(text: '${f.t('ver.correction')}: ${stillNeeds.map((d) => f.t(documentLabelKey(d.kind))).join(', ')}'),
          ],
        );
      },
    );
  }
}

class ResubmittedScreen extends ConsumerWidget {
  const ResubmittedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final loc = MaterialLocalizations.of(context);
    final last = ref.watch(lastResubmittedProvider);
    return AQAuthScaffold(
      showLogo: false,
      centered: true,
      title: f.t('rd.title'),
      subtitle: f.t('rd.body'),
      onBack: () => context.go('/verification'),
      backLabel: f.t('common.back'),
      bottom: AQPrimaryButton(label: f.t('submitted.cta'), onPressed: () => context.go('/verification')),
      children: [
        const SizedBox(height: AQSpacing.x4),
        const AQAnimatedCheck(size: 96),
        const SizedBox(height: AQSpacing.x5),
        AQStatusBadge(grant: GrantState.pendingVerification, stage: ref.watch(verificationProvider).valueOrNull?.stage),
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('submitted.nextBody'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        const SizedBox(height: AQSpacing.x5),
        if (last != null) ...[
          Text(f.t('rd.at', {'d': '${loc.formatMediumDate(last.at)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(last.at))}'}), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
          const SizedBox(height: AQSpacing.x4),
          Text(f.t('rd.changed'), style: AQTypography.of(context, AQText.titleSmall)),
          for (final k in last.changed) Padding(padding: const EdgeInsets.only(top: 4), child: Text(f.t(documentLabelKey(k)), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
        ],
      ],
    );
  }
}

/// DEMO ONLY: drives the simulated reviewer so every state can be reviewed.
class _DemoControls extends ConsumerWidget {
  const _DemoControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final api = ref.read(accountApiProvider);
    if (api is! DemoAccountApi) return const SizedBox.shrink();
    void go(void Function() fn) {
      fn();
      ref.invalidate(verificationProvider);
    }

    Widget chip(String label, VoidCallback onTap) => AQPressable(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 40),
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: AQSpacing.x2),
            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AQRadius.small + 8)),
            child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(f.t('ver.demoTitle'), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
        const SizedBox(height: AQSpacing.x2),
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
          chip(f.t('badge.pendingVerification'), () => go(() => api.demoSimulate(GrantState.pendingVerification))),
          chip(f.t('badge.awaitingSecond'), () => go(api.demoAwaitSecondApproval)),
          chip(f.t('badge.approved'), () => go(() => api.demoSimulate(GrantState.approved))),
          chip(f.t('badge.resubmissionRequired'), () => go(() => api.demoSimulate(GrantState.resubmissionRequired))),
          chip(f.t('badge.rejected'), () => go(() => api.demoSimulate(GrantState.rejected))),
          chip(f.t('badge.suspended'), () => go(() => api.demoSimulate(GrantState.suspended))),
        ]),
      ]),
    );
  }
}
