import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../devbuild/db_widgets.dart' show DbErrorCard, DbNotice;
import '../workspace/aq_thumb.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart'
    show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'engagement_models.dart';
import 'engagement_repository.dart';

(AQTone, String) _look(EngagementPhase p) => switch (p) {
  EngagementPhase.awaitingProfessional => (AQTone.pending, 'clock'),
  EngagementPhase.awaitingMe => (AQTone.warning, 'alert'),
  EngagementPhase.confirmed => (AQTone.success, 'check'),
  EngagementPhase.expired => (AQTone.neutral, 'clock'),
  EngagementPhase.declined => (AQTone.danger, 'close'),
  EngagementPhase.cancelled => (AQTone.neutral, 'close'),
};

class EngagementPhasePill extends StatelessWidget {
  final EngagementPhase phase;
  const EngagementPhasePill(this.phase, {super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final (tone, icon) = _look(phase);
    return AQStatusPill(
      label: f.t('ce.ph.${phase.name}'),
      tone: tone,
      icon: icon,
      dense: true,
    );
  }
}

// ------------------------------------------------------------------ request

class EngageRequestScreen extends ConsumerStatefulWidget {
  final String professionalId, name, type;
  const EngageRequestScreen({
    super.key,
    required this.professionalId,
    required this.name,
    required this.type,
  });
  @override
  ConsumerState<EngageRequestScreen> createState() => _RequestState();
}

class _RequestState extends ConsumerState<EngageRequestScreen> {
  bool _busy = false;
  EngagementEdge? _edge;
  String? _existingId;

  Future<void> _send() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _edge = null;
    });
    try {
      final e = await ref
          .read(engagementRepositoryProvider)
          .request(
            professionalId: widget.professionalId,
            professionalName: widget.name,
            professionalType: widget.type,
          );
      ref.invalidate(engagementsProvider);
      if (mounted) context.go('/engagements/${e.id}');
    } on DuplicateEngagementException catch (e) {
      if (mounted) {
        setState(() {
          _edge = EngagementEdge.duplicate;
          _existingId = e.existingId;
        });
      }
    } on EngagementIneligibleException catch (e) {
      if (mounted) {
        setState(
          () => _edge = switch (e.reason) {
            EngagementIneligibleReason.relatedAccount =>
              EngagementEdge.relatedAccount,
            EngagementIneligibleReason.professionalUnavailable ||
            EngagementIneligibleReason.serviceUnavailable =>
              EngagementEdge.professionalUnavailable,
            _ => EngagementEdge.ineligible,
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _edge = EngagementEdge.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/business/${widget.professionalId}');
    final signedIn = ref.watch(meProvider).hasValue;
    final edge = _edge;
    if (edge != null) {
      final retry = edge == EngagementEdge.error;
      final dup = edge == EngagementEdge.duplicate;
      return AQViewingScaffold(
        title: f.t('ce.req.title'),
        backLabel: f.t('common.back'),
        onBack: back,
        bottom: AQBottomActionBar(
          primary: AQPrimaryButton(
            label: retry
                ? f.t('ce.edge.retry')
                : (dup ? f.t('ce.edge.duplicate.cta') : f.t('ce.edge.back')),
            trailingChevron: false,
            onPressed: retry
                ? _send
                : (dup && _existingId != null
                      ? () => context.go('/engagements/$_existingId')
                      : back),
          ),
        ),
        children: [
          AQNoticeCard(
            icon: retry ? 'alert' : 'info',
            title: f.t('ce.edge.${edge.name}.t'),
            body: f.t('ce.edge.${edge.name}.b'),
            tone: retry ? AQTone.warning : AQTone.neutral,
          ),
        ],
      );
    }
    return AQViewingScaffold(
      title: f.t('ce.req.title'),
      subtitle: f.t('ce.req.sub', {'name': VFmt.iso(widget.name)}),
      backLabel: f.t('common.back'),
      onBack: back,
      bottom: AQBottomActionBar(
        primary: signedIn
            ? AQPrimaryButton(
                label: f.t('ce.req.send'),
                trailingChevron: false,
                loading: _busy,
                onPressed: _busy ? null : _send,
              )
            : AQPrimaryButton(
                label: f.t('ce.req.login'),
                trailingChevron: false,
                onPressed: () => context.push('/login'),
              ),
      ),
      children: [
        AQViewingSectionTitle(f.t('ce.req.what.t')),
        Text(
          f.t('ce.req.what.b'),
          style: AQTypography.of(context, AQText.bodyMedium),
        ),
        AQViewingSectionTitle(f.t('ce.req.rules.t')),
        AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1. ${f.t('ce.req.rules.1')}',
                style: AQTypography.of(context, AQText.bodyMedium),
              ),
              const SizedBox(height: AQSpacing.x1),
              Text(
                '2. ${f.t('ce.req.rules.2')}',
                style: AQTypography.of(context, AQText.bodyMedium),
              ),
            ],
          ),
        ),
        if (!signedIn)
          Padding(
            padding: const EdgeInsets.only(top: AQSpacing.x3),
            child: DbNotice(f.t('ce.req.signin'), icon: 'lock'),
          ),
        const SizedBox(height: AQSpacing.x4),
        if (kUseDemoBackend) DbNotice(f.t('ce.req.demo'), icon: 'info'),
      ],
    );
  }
}

// ------------------------------------------------------------------ list

class MyEngagementsScreen extends ConsumerWidget {
  const MyEngagementsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/app/account');
    final now = DateTime.now();
    return AQViewingScaffold(
      title: f.t('ce.list.title'),
      subtitle: f.t('ce.list.sub'),
      backLabel: f.t('common.back'),
      onBack: back,
      children: [
        ref
            .watch(engagementsProvider)
            .when(
              loading: () => const AQViewingSkeleton(height: 84),
              error: (e, _) => DbErrorCard(
                error: e,
                onRetry: () => ref.invalidate(engagementsProvider),
              ),
              data: (list) => list.isEmpty
                  ? AQEmptyViewingState(
                      title: f.t('ce.list.empty.t'),
                      body: f.t('ce.list.empty.b'),
                      action: AQPrimaryButton(
                        label: f.t('ce.list.cta'),
                        trailingChevron: false,
                        onPressed: () => context.push('/professionals'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final e in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AQSpacing.x3,
                            ),
                            child: _Card(e, e.phaseAt(now)),
                          ),
                      ],
                    ),
            ),
        const SizedBox(height: AQSpacing.x4),
        if (kUseDemoBackend) DbNotice(f.t('ce.req.demo'), icon: 'info'),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final ClientEngagement e;
  final EngagementPhase phase;
  const _Card(this.e, this.phase);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${e.professionalName}, ${f.t('ce.ph.${phase.name}')}',
      excludeSemantics: true,
      onTap: () => context.push('/engagements/${e.id}'),
      child: AQPressable(
        onTap: () => context.push('/engagements/${e.id}'),
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Row(
            children: [
              aqRowLead(AQThumb(asset: businessCoverById(e.professionalId), monogramOf: e.professionalName)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      VFmt.iso(e.professionalName),
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    Text(
                      VFmt.shortDate(context, e.requestedAt),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x2),
                    EngagementPhasePill(phase),
                  ],
                ),
              ),
              const AQIcon('chevron-right', size: 18, directional: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ detail

class EngagementDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const EngagementDetailScreen({super.key, required this.id});
  @override
  ConsumerState<EngagementDetailScreen> createState() => _DetailState();
}

class _DetailState extends ConsumerState<EngagementDetailScreen> {
  bool _busy = false;
  String? _doneKey, _errorKey;

  Future<void> _run(
    Future<ClientEngagement> Function(EngagementRepository r) op,
    String done,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _doneKey = null;
      _errorKey = null;
    });
    try {
      await op(ref.read(engagementRepositoryProvider));
      ref.invalidate(engagementProvider(widget.id));
      ref.invalidate(engagementsProvider);
      if (mounted) setState(() => _doneKey = done);
    } catch (_) {
      ref.invalidate(engagementProvider(widget.id));
      if (mounted) setState(() => _errorKey = 'ce.d.err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/engagements');
    Widget shell(List<Widget> children, {Widget? bottom}) => AQViewingScaffold(
      title: f.t('ce.d.title'),
      backLabel: f.t('common.back'),
      onBack: back,
      bottom: bottom,
      children: children,
    );
    return ref
        .watch(engagementProvider(widget.id))
        .when(
          loading: () => shell(const [AQViewingSkeleton(height: 96)]),
          error: (e, _) => shell([
            DbErrorCard(
              error: e,
              onRetry: () => ref.invalidate(engagementProvider(widget.id)),
            ),
          ]),
          data: (e) {
            if (e == null) {
              return shell([
                AQNoticeCard(
                  icon: 'info',
                  title: f.t('ce.d.notFound'),
                  body: '',
                ),
              ]);
            }
            final now = DateTime.now();
            final phase = e.phaseAt(now);
            final (tone, icon) = _look(phase);
            Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 130,
                    child: Text(
                      k,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      v,
                      style: AQTypography.of(context, AQText.bodyMedium),
                    ),
                  ),
                ],
              ),
            );
            Widget? bottom;
            if (phase == EngagementPhase.confirmed && e.reviewOpenAt(now)) {
              bottom = AQBottomActionBar(
                primary: AQPrimaryButton(
                  label: f.t('ce.d.review'),
                  trailingChevron: false,
                  onPressed: () => context.push(
                    '/review/professional/${e.professionalId}?name=${Uri.encodeComponent(e.professionalName)}',
                  ),
                ),
              );
            } else if (phase == EngagementPhase.awaitingMe) {
              bottom = AQBottomActionBar(
                primary: AQPrimaryButton(
                  label: f.t('ce.d.confirm'),
                  trailingChevron: false,
                  loading: _busy,
                  onPressed: _busy
                      ? null
                      : () => _run((r) => r.confirm(e.id), 'ce.d.done.confirm'),
                ),
              );
            } else if (phase == EngagementPhase.awaitingProfessional) {
              bottom = AQBottomActionBar(
                primary: AQSecondaryButton(
                  label: f.t('ce.d.cancel'),
                  trailingChevron: false,
                  onPressed: _busy
                      ? null
                      : () => _run((r) => r.cancel(e.id), 'ce.d.done.cancel'),
                ),
              );
            }
            return shell([
              if (_doneKey != null)
                AQErrorBanner(tone: AQBannerTone.success, text: f.t(_doneKey!)),
              if (_errorKey != null) AQErrorBanner(text: f.t(_errorKey!)),
              const SizedBox(height: AQSpacing.x2),
              Text(
                VFmt.iso(e.professionalName),
                style: AQTypography.of(context, AQText.headlineMedium),
              ),
              const SizedBox(height: AQSpacing.x2),
              AQNoticeCard(
                icon: icon,
                title: f.t('ce.ph.${phase.name}'),
                body: f.t('ce.ex.${phase.name}'),
                tone: tone,
              ),
              AQViewingSectionTitle(f.t('ce.d.title')),
              AQSurface(
                padding: const EdgeInsets.all(AQSpacing.x4),
                child: Column(
                  children: [
                    row(
                      f.t('ce.d.requested'),
                      VFmt.fullDate(context, e.requestedAt),
                    ),
                    if (e.isWaiting && phase == e.phase)
                      row(
                        f.t('ce.d.confirmBy'),
                        VFmt.fullDate(context, e.confirmBy),
                      ),
                    if (e.reviewBy != null &&
                        phase == EngagementPhase.confirmed)
                      row(
                        f.t('ce.d.reviewBy'),
                        VFmt.fullDate(context, e.reviewBy!),
                      ),
                  ],
                ),
              ),
              if (kShowReviewTools) _QaEngagement(e),
              const SizedBox(height: AQSpacing.x4),
              if (kUseDemoBackend) DbNotice(f.t('ce.req.demo'), icon: 'info'),
            ], bottom: bottom);
          },
        );
  }
}

/// QA only (`REVIEW_TOOLS`): stands in for the professional. Never in a production build.
class _QaEngagement extends ConsumerWidget {
  final ClientEngagement e;
  const _QaEngagement(this.e);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(engagementRepositoryProvider);
    if (repo is! DemoEngagementRepository) return const SizedBox.shrink();
    void set(EngagementPhase p, {DateTime? requestedAt}) {
      repo.debugSet(e.id, p, requestedAt: requestedAt);
      ref.invalidate(engagementProvider(e.id));
      ref.invalidate(engagementsProvider);
    }

    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: AQSurface(
        padding: const EdgeInsets.all(AQSpacing.x3),
        child: Wrap(
          spacing: AQSpacing.x2,
          children: [
            Text(
              'QA only: simulate the professional',
              style: AQTypography.of(context, AQText.labelMedium, soft: true),
            ),
            AQTextButton(
              label: 'Professional confirms',
              onPressed: () => set(EngagementPhase.confirmed),
            ),
            AQTextButton(
              label: 'Professional declines',
              onPressed: () => set(EngagementPhase.declined),
            ),
            AQTextButton(
              label: 'Professional asks you first',
              onPressed: () => set(EngagementPhase.awaitingMe),
            ),
            AQTextButton(
              label: 'Let the 14 days pass',
              onPressed: () => set(
                e.phase,
                requestedAt: DateTime.now().subtract(
                  const Duration(days: kEngagementConfirmDays + 1),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
