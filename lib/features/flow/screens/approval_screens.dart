import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_auth_scaffold.dart';
import '../../../core/aq/aq_documents.dart';
import '../../../core/aq/aq_forms.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/domain/account_models.dart';
import '../../../core/localization/flow_strings.dart';
import '../../../data/api/account_api.dart';
import '../../entry/models/signup_purpose.dart';
import '../../entry/widgets/entry_common.dart' show MasterLogo;
import '../widgets/document_upload_tile.dart';
import '../widgets/flow_common.dart';

/// The emotional payoff: restrained, one drawn check, four lines that arrive in
/// sequence. Shown only when the server says the grant is approved.
class ApprovedScreen extends ConsumerStatefulWidget {
  const ApprovedScreen({super.key});
  @override
  ConsumerState<ApprovedScreen> createState() => _ApprovedScreenState();
}

class _ApprovedScreenState extends ConsumerState<ApprovedScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _seq = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
  bool _felt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AQMotion.reduced(context) ? _seq.value = 1 : _seq.forward();
    });
  }

  @override
  void dispose() {
    _seq.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('ap.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('ap.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        if (info.grant != GrantState.approved) {
          // Never celebrate something the server has not approved.
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/verification'));
          return const SizedBox.shrink();
        }
        if (!_felt) {
          _felt = true;
          // One meaningful haptic, once, when the verified state appears.
          WidgetsBinding.instance.addPostFrameCallback((_) => AQHaptics.success());
        }
        Widget line(int i, String key) => AQReveal(
              animation: _seq,
              begin: 0.35 + i * 0.13,
              end: 0.55 + i * 0.13,
              dy: 8,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(children: [
                  AQIcon('check', size: AQIconSize.medium, color: c.success),
                  const SizedBox(width: AQSpacing.x3),
                  Text(f.t(key), style: AQTypography.of(context, AQText.titleSmall)),
                ]),
              ),
            );
        return AQAuthScaffold(
          showLogo: false,
          centered: true,
          title: f.t('ap.title'),
          subtitle: f.t('ap.sub'),
          onBack: () => context.go('/verification'),
          backLabel: f.t('common.back'),
          bottom: AQPrimaryButton(label: f.t('ver.action.continue'), onPressed: () => context.go('/verification/summary')),
          children: [
            const SizedBox(height: AQSpacing.x4),
            // Warm light blooms behind the check as it forms.
            SizedBox(
              height: 168,
              child: Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
                AnimatedBuilder(
                  animation: _seq,
                  builder: (context, _) => Opacity(
                    opacity: Curves.easeOut.transform((_seq.value * 1.4).clamp(0.0, 1.0)),
                    child: Container(
                      width: 300,
                      height: 300,
                      decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [c.accent.withValues(alpha: c.isDark ? 0.22 : 0.20), c.accent.withValues(alpha: 0)])),
                    ),
                  ),
                ),
                const AQAnimatedCheck(size: 112),
              ]),
            ),
            const SizedBox(height: AQSpacing.x4),
            AQReveal(animation: _seq, begin: 0.25, end: 0.6, dy: 6, child: MasterLogo(width: 128)),
            const SizedBox(height: AQSpacing.x6),
            Align(alignment: Alignment.center, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [line(0, 'ap.1'), line(1, 'ap.2'), line(2, 'ap.3'), line(3, 'ap.4')])),
          ],
        );
      },
    );
  }
}

class VerifiedSummaryScreen extends ConsumerWidget {
  const VerifiedSummaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final loc = MaterialLocalizations.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('sum.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('sum.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        if (info.grant != GrantState.approved) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/verification'));
          return const SizedBox.shrink();
        }
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('sum.title'),
          onBack: () => context.go('/verification/approved'),
          backLabel: f.t('common.back'),
          progress: Align(alignment: AlignmentDirectional.centerStart, child: AQStatusBadge(grant: info.grant)),
          bottom: AQPrimaryButton(label: f.t('sum.cta'), onPressed: () => context.go('/workspace/activation')),
          children: [
            AQReviewSection(title: f.t('sum.identity'), children: [
              if (info.businessName != null) AQKeyValue(f.t('det.company'), info.businessName!),
              AQKeyValue(f.t('det.type'), roleTitle(context, info.purpose)),
              if (info.decidedAt != null) AQKeyValue(f.t('sum.at'), '${loc.formatMediumDate(info.decidedAt!)} · ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(info.decidedAt!))}'),
              AQKeyValue(f.t('sum.profile'), f.t('sum.profileActive')),
            ]),
            AQReviewSection(title: f.t('sum.docs'), children: [for (final d in info.documents) AQDocumentRow(title: f.t(documentLabelKey(d.kind)), status: d)]),
          ],
        );
      },
    );
  }
}

/// Only what the approved role actually unlocks.
List<String> workspaceCaps(SignupPurpose p) => switch (p) {
      SignupPurpose.realEstateAgent => ['ws.cap.agent.1', 'ws.cap.agent.2', 'ws.cap.agent.3'],
      SignupPurpose.propertyDevelopmentCompany => ['ws.cap.dev.1', 'ws.cap.dev.2'],
      SignupPurpose.userToShop => const [],
      _ => ['ws.cap.pro.1', 'ws.cap.pro.2'],
    };

/// Role-aware handoff: names the workspace for the approved role.
class WorkspaceActivationScreen extends ConsumerWidget {
  const WorkspaceActivationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final v = ref.watch(verificationProvider);
    return v.when(
      loading: () => aqLoadingFrame(context, title: f.t('ws.title')),
      error: (e, _) => aqErrorFrame(context, ref, title: f.t('ws.title'), onRetry: () => ref.invalidate(verificationProvider), error: e),
      data: (info) {
        if (info.grant != GrantState.approved) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/verification'));
          return const SizedBox.shrink();
        }
        return AQAuthScaffold(
          showLogo: false,
          title: f.t('ws.t.${info.purpose.name}'),
          subtitle: '${roleTitle(context, info.purpose)} · ${f.t('ws.sub')}',
          onBack: () => context.go('/verification/summary'),
          backLabel: f.t('common.back'),
          bottom: AQPrimaryButton(label: f.t('ws.cta'), onPressed: () => context.go('/app/home')),
          children: [
            AQSurface(
              padding: const EdgeInsets.all(AQSpacing.x4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final k in workspaceCaps(info.purpose))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon('check', size: AQIconSize.medium, color: c.accent)),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(child: Text(f.t(k), style: AQTypography.of(context, AQText.bodyLarge))),
                    ]),
                  ),
              ]),
            ),
          ],
        );
      },
    );
  }
}
