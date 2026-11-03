import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_documents.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart' show AQAnimatedSize;
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../core/config/backend_mode.dart';
import '../../../data/api/account_api.dart';
import '../../../data/demo/demo_backend.dart';
import '../state/document_state.dart';
import '../widgets/document_preview.dart';
import '../widgets/document_upload_tile.dart';
import '../widgets/flow_common.dart';
import '../widgets/journey.dart';

/// Role-specific explanation of why and what we verify, before any upload.
class VerificationIntroScreen extends ConsumerWidget {
  const VerificationIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final me = ref.watch(meProvider);
    return me.when(
      loading: () => aqLoadingFrame(context, title: f.t('vintro.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('vintro.title'), onRetry: () => ref.invalidate(meProvider), error: e),
      data: (m) {
        final cfg = m.purpose == null ? null : roleConfigs[m.purpose];
        if (cfg == null || !cfg.needsDocuments) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/app/home'));
          return const SizedBox.shrink();
        }
        Widget bullet(String key, {Widget? lead}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                lead ?? Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon('check', size: AQIconSize.small, color: c.accent)),
                const SizedBox(width: AQSpacing.x3),
                Expanded(child: Text(f.t(key), style: AQTypography.of(context, AQText.bodyMedium))),
              ]),
            );
        Widget step(int n, String key) => bullet(
              key,
              lead: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14), shape: BoxShape.circle),
                child: Text('$n', style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
              ),
            );
        return AQAuthScaffold(
          title: f.t('vintro.title'),
          subtitle: f.t('vintro.sub'),
          onBack: () => context.go('/account/active'),
          backLabel: f.t('common.back'),
          progress: journeyProgress(context, m.purpose!, JourneyAt.documents),
          bottom: AQPrimaryButton(label: f.t('vintro.cta'), onPressed: () => context.go('/onboarding/documents')),
          children: [
            AQReviewSection(title: f.t('vintro.why.title'), children: [const SizedBox(height: 4), for (final k in ['vintro.trust', 'vintro.authenticity', 'vintro.safety']) bullet(k)]),
            AQReviewSection(title: f.t('vintro.what.title'), children: [const SizedBox(height: 4), for (final k in ['vintro.what.1', 'vintro.what.2', 'vintro.what.3', 'vintro.what.4']) bullet(k)]),
            AQReviewSection(
              title: f.t('vintro.yours'),
              children: [
                const SizedBox(height: 4),
                for (final d in cfg.documents) bullet(documentLabelKey(d)),
                Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('vintro.formats'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                if (cfg.fourEyes) Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('docs.fourEyes'), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              ],
            ),
            AQReviewSection(title: f.t('vintro.next.title'), children: [const SizedBox(height: 4), step(1, 'vintro.next.1'), step(2, 'vintro.next.2'), step(3, 'vintro.next.3')]),
            AQErrorBanner(tone: AQBannerTone.info, text: f.t('vintro.secure')),
          ],
        );
      },
    );
  }
}

/// Initial package: one independent tile per required document.
class DocumentOnboardingScreen extends ConsumerWidget {
  const DocumentOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    final ver = ref.watch(verificationProvider);
    return me.when(
      loading: () => aqLoadingFrame(context, title: f.t('docs.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('docs.title'), onRetry: () => ref.invalidate(meProvider), error: e),
      data: (m) {
        final cfg = m.purpose == null ? null : roleConfigs[m.purpose];
        if (cfg == null || !cfg.needsDocuments) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/app/home'));
          return const SizedBox.shrink();
        }
        final server = {for (final d in ver.valueOrNull?.documents ?? const <DocumentStatus>[]) d.kind: d};
        final allDone = cfg.documents.every((k) => ref.watch(documentControllerProvider(k)).phase == DocPhase.success);
        final anyBusy = cfg.documents.any((k) => ref.watch(documentControllerProvider(k)).busy);
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('docs.title'),
          subtitle: f.t('docs.sub'),
          onBack: () => aqBackTo(context, '/onboarding/verification-intro'),
          backLabel: f.t('common.back'),
          progress: journeyProgress(context, m.purpose!, JourneyAt.documents),
          bottom: Column(mainAxisSize: MainAxisSize.min, children: [
            // The prerequisite hint folds away smoothly once every document is in.
            AQAnimatedSize(
              duration: AQMotion.scaled(context, AQMotion.state),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: AQMotion.scaled(context, AQMotion.state),
                child: allDone
                    ? const SizedBox(key: ValueKey('ready'), width: double.infinity)
                    : Padding(key: const ValueKey('hint'), padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: Text(f.t('review.incomplete'), style: AQTypography.of(context, AQText.bodySmall, color: AQColors.of(context).inkFaint))),
              ),
            ),
            AQPrimaryButton(label: f.t('docs.review'), onPressed: allDone && !anyBusy
                  ? () {
                      // Uploads changed the server state; the review must not read a cached copy.
                      ref.invalidate(verificationProvider);
                      context.go('/onboarding/review');
                    }
                  : null),
          ]),
          children: [
            if (cfg.fourEyes) AQErrorBanner(tone: AQBannerTone.info, text: f.t('docs.fourEyes')),
            if (kShowReviewTools && ref.read(accountApiProvider) is DemoAccountApi)
              AQTextButton(
                label: 'DEMO: mark all documents received',
                onPressed: () {
                  (ref.read(accountApiProvider) as DemoAccountApi).demoAttachAll();
                  ref.invalidate(verificationProvider);
                  context.go('/onboarding/review');
                },
              ),
            for (final k in cfg.documents) DocumentUploadTile(key: ValueKey(k), kind: k, seed: initialFromStatus(server[k])),
          ],
        );
      },
    );
  }
}

void aqBackTo(BuildContext context, String route) => context.go(route);

/// The final checkpoint before submitting. Each section can be corrected where correction is possible.
class ApplicationReviewScreen extends ConsumerStatefulWidget {
  const ApplicationReviewScreen({super.key});
  @override
  ConsumerState<ApplicationReviewScreen> createState() => _ApplicationReviewScreenState();
}

class _ApplicationReviewScreenState extends ConsumerState<ApplicationReviewScreen> {
  bool _submitting = false;
  String? _bannerKey;

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() {
      _submitting = true;
      _bannerKey = null;
    });
    try {
      await ref.read(accountApiProvider).submitVerification();
      ref.invalidate(meProvider);
      ref.invalidate(verificationProvider);
      AQHaptics.success();
      if (mounted) context.go('/onboarding/submitted');
    } catch (e) {
      if (mounted) setState(() => _bannerKey = apiErrorKey(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final ver = ref.watch(verificationProvider);
    final last4 = ref.watch(meProvider).valueOrNull?.phoneLast4;
    return ver.when(
      loading: () => aqLoadingFrame(context, title: f.t('review.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('review.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (v) {
        final complete = v.documents.every((d) => d.outcome != DocumentOutcome.notSubmitted);
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('review.title'),
          subtitle: f.t('review.sub'),
          onBack: () => context.go('/onboarding/documents'),
          backLabel: f.t('common.back'),
          progress: journeyProgress(context, v.purpose, JourneyAt.review),
          bottom: Column(mainAxisSize: MainAxisSize.min, children: [
            if (_bannerKey != null) AQErrorBanner(text: f.t(_bannerKey!)),
            AQPrimaryButton(label: f.t('review.submit'), loading: _submitting, onPressed: complete ? _submit : null),
          ]),
          children: [
            AQReviewSection(title: f.t('review.details'), children: [
              AQKeyValue(f.t('review.role'), roleTitle(context, v.purpose)),
              if (last4 != null) AQKeyValue(f.t('review.mobile'), '+968 •••• $last4'),
            ]),
            if (v.businessName != null)
              AQReviewSection(title: f.t('review.business'), children: [
                AQKeyValue(f.t('review.name'), v.businessName!),
              ]),
            AQReviewSection(
              title: f.t('review.documents'),
              editLabel: f.t('review.edit'),
              onEdit: () => context.go('/onboarding/documents'),
              children: [for (final d in v.documents) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d, onTap: d.fileName == null ? null : () => showDocumentPreview(context, d.kind, status: d))],
            ),
            AQReviewSection(title: f.t('review.consent'), children: [Padding(padding: const EdgeInsets.only(top: AQSpacing.x2), child: Text(f.t('review.consentBody'), style: AQTypography.of(context, AQText.bodySmall, soft: true)))]),
            // A calm "ready" note rather than a government-style checklist.
            AnimatedSwitcher(
              duration: AQMotion.scaled(context, AQMotion.standard),
              child: complete
                  ? Container(
                      key: const ValueKey('ready'),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AQSpacing.x4),
                      padding: const EdgeInsets.all(AQSpacing.x4),
                      decoration: BoxDecoration(color: c.success.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(AQRadius.medium)),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AQIcon('check', size: AQIconSize.medium, color: c.success),
                        const SizedBox(width: AQSpacing.x3),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(f.t('review.ready'), style: AQTypography.of(context, AQText.titleSmall)),
                            Text(f.t('review.readyBody'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                          ]),
                        ),
                      ]),
                    )
                  : const SizedBox.shrink(key: ValueKey('notready')),
            ),
          ],
        );
      },
    );
  }
}

/// Submission is never approval: this screen says "submitted for verification".
class ApplicationSubmittedScreen extends ConsumerWidget {
  const ApplicationSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final info = ref.watch(verificationProvider).valueOrNull;
    final c = AQColors.of(context);
    return AQAuthScaffold(
      showLogo: false,
      centered: true,
      showBack: false,
      progress: info == null ? null : journeyProgress(context, info.purpose, JourneyAt.status),
      title: f.t('submitted.title'),
      subtitle: f.t('submitted.body'),
      bottom: AQPrimaryButton(label: f.t('submitted.cta'), onPressed: () => context.go('/verification')),
      children: [
        const SizedBox(height: AQSpacing.x6),
        const AQAnimatedCheck(size: 104),
        if (info?.reference != null) ...[const SizedBox(height: AQSpacing.x6), Text('${f.t('submitted.ref')}: ${info!.reference}', style: AQTypography.of(context, AQText.labelMedium, soft: true))],
        if (info != null) ...[
          const SizedBox(height: AQSpacing.x5),
          AQStatusBadge(grant: info.grant == GrantState.draft ? GrantState.pendingVerification : info.grant, stage: info.stage),
          const SizedBox(height: AQSpacing.x4),
          Text(f.t('submitted.nextBody'), textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, color: c.inkSoft)),
        ],
      ],
    );
  }
}
