import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../../data/models/enums.dart';
import '../devbuild/db_models.dart' show PermissionDeniedException;
import '../devbuild/db_widgets.dart' show DbErrorCard, DbNotice, DbPillRow;
import '../role_home/role_home_model.dart';
import '../viewing/domain/viewing_models.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart'
    show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg;
import 'lead_models.dart';
import 'lead_repository.dart';
import 'phone_launcher.dart';

// ------------------------------------------------------------------ scope helpers

String _prefix(LeadScope s) => switch (s) {
  LeadScope.agent => 'agent',
  LeadScope.developer => 'dev',
  LeadScope.service => 'svc',
};

String _listRoute(LeadScope s) => switch (s) {
  LeadScope.agent => '/agent/leads',
  LeadScope.developer => '/workspace/enquiries',
  LeadScope.service => '/workspace/requests',
};

String detailRoute(LeadScope s, String id) => '${_listRoute(s)}/$id';

bool _allowed(LeadScope s, HomeResolution r) => switch (s) {
  LeadScope.agent => r.canSwitch,
  LeadScope.developer => r.role == HomeRole.developer,
  LeadScope.service =>
    r.role == HomeRole.construction ||
        r.role == HomeRole.architecture ||
        r.role == HomeRole.interiorExterior,
};

/// Each inbox belongs to one role. The screen is hidden from everyone else; the service enforces
/// the same rule on the data.
class LeadGuard extends ConsumerWidget {
  final LeadScope scope;
  final String title;
  final String backFallback;
  final Widget Function(BuildContext context) builder;
  const LeadGuard({
    super.key,
    required this.scope,
    required this.title,
    required this.backFallback,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    void back() => aqBack(context, backFallback);
    if (me.isLoading && !me.hasValue) {
      return AQViewingScaffold(
        title: title,
        backLabel: f.t('common.back'),
        onBack: back,
        children: const [
          AQViewingSkeleton(height: 96),
          AQViewingSkeleton(height: 96),
        ],
      );
    }
    if (!_allowed(scope, resolveHome(me.valueOrNull))) {
      final p = _prefix(scope);
      return AQViewingScaffold(
        title: title,
        backLabel: f.t('common.back'),
        onBack: back,
        bottom: AQBottomActionBar(
          primary: AQPrimaryButton(
            label: f.t('common.back'),
            trailingChevron: false,
            onPressed: () => context.go('/app/home'),
          ),
        ),
        children: [
          AQNoticeCard(
            icon: 'lock',
            title: f.t('ld.noAccess.$p.t'),
            body: f.t('ld.noAccess.$p.b'),
          ),
        ],
      );
    }
    return builder(context);
  }
}

(AQTone, String) _viewingLook(ViewingStatus s) => switch (s) {
  ViewingStatus.requested => (AQTone.pending, 'clock'),
  ViewingStatus.confirmed => (AQTone.success, 'calendar-check'),
  ViewingStatus.declined => (AQTone.danger, 'calendar-x'),
  ViewingStatus.cancelled => (AQTone.neutral, 'close'),
  ViewingStatus.completed => (AQTone.success, 'check'),
};

class _ViewingPill extends StatelessWidget {
  final ViewingStatus status;
  const _ViewingPill(this.status);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final (tone, icon) = _viewingLook(status);
    return AQStatusPill(
      label: f.t('ld.vw.${status.name}'),
      tone: tone,
      icon: icon,
      dense: true,
    );
  }
}

String _title(FlowStrings f, Lead l) => switch (l.kind) {
  LeadKind.projectEnquiry => l.projectName ?? f.t('ld.card.noContext'),
  LeadKind.serviceRequest =>
    l.serviceCategory?.label ?? f.t('ld.card.noContext'),
  _ => l.propertyTitle ?? f.t('ld.card.noContext'),
};

String? _image(Lead l) =>
    l.kind == LeadKind.projectEnquiry ? l.projectImage : l.propertyImage;

String _kindIcon(LeadKind k) => switch (k) {
  LeadKind.contact => 'phone',
  LeadKind.viewingRequest => 'calendar',
  LeadKind.projectEnquiry => 'development',
  LeadKind.serviceRequest => 'construction',
};

// ------------------------------------------------------------------ card

class LeadCard extends StatelessWidget {
  final Lead lead;
  final VoidCallback onOpen;
  const LeadCard({super.key, required this.lead, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final l = lead;
    final image = _image(l);
    final name = l.customerName ?? f.t('ld.card.noName');
    final received = f.t('ld.card.received', {
      'd':
          '${VFmt.shortDate(context, l.receivedAt)} · ${VFmt.time(context, l.receivedAt)}',
    });
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label:
          '${f.t('ld.kind.${l.kind.name}')}, ${_title(f, l)}, $name, $received',
      excludeSemantics: true,
      onTap: onOpen,
      child: AQPressable(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.medium),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: image == null
                      ? ColoredBox(
                          color: c.surfaceSelected,
                          child: Center(
                            child: AQIcon(
                              _kindIcon(l.kind),
                              size: 24,
                              color: c.accent,
                            ),
                          ),
                        )
                      : aqImg(image, cacheWidth: 300),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.t('ld.kind.${l.kind.name}'),
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        color: c.accentDeep,
                      ),
                    ),
                    Text(
                      VFmt.iso(_title(f, l)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AQTypography.of(context, AQText.titleMedium),
                    ),
                    Text(
                      '${VFmt.iso(name)} · $received',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                    if (l.viewingStatus != null || l.status != null) ...[
                      const SizedBox(height: AQSpacing.x2),
                      if (l.viewingStatus != null)
                        _ViewingPill(l.viewingStatus!)
                      else
                        AQStatusPill(
                          label: l.status!,
                          tone: AQTone.neutral,
                          dense: true,
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: AQSpacing.x1),
                child: AQIcon(
                  'chevron-right',
                  size: 18,
                  color: c.inkSoft,
                  directional: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ inbox

class LeadInboxScreen extends ConsumerStatefulWidget {
  final LeadScope scope;
  const LeadInboxScreen({super.key, required this.scope});
  @override
  ConsumerState<LeadInboxScreen> createState() => _LeadInboxScreenState();
}

class _LeadInboxScreenState extends ConsumerState<LeadInboxScreen> {
  // One filter at a time per scope: kind for agents, project for developers, service for companies.
  Object? _pick;
  ViewingStatus? _status;

  bool _kindMatches(Lead l) {
    final p = _pick;
    if (p == null) return true;
    return switch (widget.scope) {
      LeadScope.agent => l.kind == p,
      LeadScope.developer => l.projectId == p,
      LeadScope.service => l.serviceCategory == p,
    };
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final scope = widget.scope;
    final p = _prefix(scope);
    return LeadGuard(
      scope: scope,
      title: f.t('ld.$p.title'),
      backFallback: '/app/home',
      builder: (context) {
        final async = ref.watch(leadsProvider(scope));
        final all = async.valueOrNull ?? const <Lead>[];
        final shown = all
            .where(
              (l) =>
                  _kindMatches(l) &&
                  (_status == null || l.viewingStatus == _status),
            )
            .toList();

        // Filter pills only offer values that exist in the data, so a filter never returns nothing.
        final pills = <(String, bool, VoidCallback)>[];
        if (all.isNotEmpty) {
          pills.add((
            f.t('ld.f.all'),
            _pick == null,
            () => setState(() => _pick = null),
          ));
          switch (scope) {
            case LeadScope.agent:
              if (all.any((l) => l.kind == LeadKind.contact)) {
                pills.add((
                  f.t('ld.f.contact'),
                  _pick == LeadKind.contact,
                  () => setState(() => _pick = LeadKind.contact),
                ));
              }
              if (all.any((l) => l.kind == LeadKind.viewingRequest)) {
                pills.add((
                  f.t('ld.f.viewing'),
                  _pick == LeadKind.viewingRequest,
                  () => setState(() => _pick = LeadKind.viewingRequest),
                ));
              }
            case LeadScope.developer:
              final seen = <String>{};
              for (final l in all) {
                if (l.projectId != null && seen.add(l.projectId!)) {
                  pills.add((
                    l.projectName ?? l.projectId!,
                    _pick == l.projectId,
                    () => setState(() => _pick = l.projectId),
                  ));
                }
              }
            case LeadScope.service:
              final seen = <ServiceCategory>{};
              for (final l in all) {
                if (l.serviceCategory != null && seen.add(l.serviceCategory!)) {
                  pills.add((
                    l.serviceCategory!.label,
                    _pick == l.serviceCategory,
                    () => setState(() => _pick = l.serviceCategory),
                  ));
                }
              }
          }
        }
        final statuses = {
          for (final l in all)
            if (l.viewingStatus != null) l.viewingStatus!,
        };

        Widget body;
        if (async.isLoading && !async.hasValue) {
          body = const Column(
            key: ValueKey('load'),
            children: [
              AQViewingSkeleton(height: 96),
              AQViewingSkeleton(height: 96),
              AQViewingSkeleton(height: 96),
            ],
          );
        } else if (async.hasError && !async.hasValue) {
          body = DbErrorCard(
            key: const ValueKey('err'),
            error: async.error,
            onRetry: () => ref.invalidate(leadsProvider(scope)),
          );
        } else if (all.isEmpty) {
          body = AQEmptyViewingState(
            key: const ValueKey('empty'),
            title: f.t('ld.empty.$p.t'),
            body: f.t('ld.empty.$p.b'),
            action: scope == LeadScope.agent
                ? AQPrimaryButton(
                    label: f.t('ld.empty.agent.cta'),
                    trailingChevron: false,
                    onPressed: () => context.push('/agent/listings'),
                  )
                : AQSecondaryButton(
                    label: f.t('ld.empty.home'),
                    trailingChevron: false,
                    onPressed: () => context.go('/app/home'),
                  ),
          );
        } else if (shown.isEmpty) {
          body = AQEmptyViewingState(
            key: const ValueKey('none'),
            title: f.t('ld.empty.filter.t'),
            body: f.t('ld.empty.filter.b'),
          );
        } else {
          body = Column(
            key: ValueKey('list-$_pick-$_status-${shown.length}'),
            children: [
              for (final l in shown)
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: LeadCard(
                    lead: l,
                    onOpen: () => context.push(detailRoute(scope, l.id)),
                  ),
                ),
            ],
          );
        }
        return AQViewingScaffold(
          title: f.t('ld.$p.title'),
          subtitle: f.t('ld.$p.sub'),
          backLabel: f.t('common.back'),
          onBack: () => aqBack(context, '/app/home'),
          children: [
            if (pills.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                child: DbPillRow(scroll: true, pills: pills),
              ),
            if (statuses.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x4),
                child: DbPillRow(
                  scroll: true,
                  pills: [
                    (
                      f.t('ld.f.all'),
                      _status == null,
                      () => setState(() => _status = null),
                    ),
                    for (final s in ViewingStatus.values)
                      if (statuses.contains(s))
                        (
                          f.t('ld.vw.${s.name}'),
                          _status == s,
                          () => setState(() => _status = s),
                        ),
                  ],
                ),
              ),
            AnimatedSwitcher(
              duration: AQMotion.scaled(context, AQMotion.fast),
              child: body,
            ),
            if (kShowReviewTools) _QaSamples(scope: scope),
          ],
        );
      },
    );
  }
}

/// QA only (`--dart-define=REVIEW_TOOLS=true`): adds clearly labelled sample leads so every state can
/// be reached. Production builds have no lead service, so they show real (empty or error) states.
class _QaSamples extends ConsumerWidget {
  final LeadScope scope;
  const _QaSamples({required this.scope});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(leadRepositoryProvider);
    if (repo is! DemoLeadRepository) return const SizedBox.shrink();
    final f = FlowStrings.of(context);
    void add(Lead Function(String id) b) {
      repo.debugAdd(scope, b);
      ref.invalidate(leadsProvider(scope));
    }

    final now = DateTime.now();
    final items = <(String, Lead Function(String))>[
      if (scope == LeadScope.agent) ...[
        (
          'contact request',
          (id) => Lead(
            id: id,
            kind: LeadKind.contact,
            receivedAt: now,
            customerName: 'Sample customer',
            phone: '+968 9000 0001',
            message: 'Is the property still available?',
            propertyId: 'p1',
            propertyTitle: 'Sample villa',
          ),
        ),
        (
          'viewing request',
          (id) => Lead(
            id: id,
            kind: LeadKind.viewingRequest,
            receivedAt: now,
            customerName: 'Sample customer',
            phone: '+968 9000 0002',
            propertyId: 'p1',
            propertyTitle: 'Sample villa',
            viewingId: 'v-$id',
            viewingStatus: ViewingStatus.requested,
            requestedSlot: ViewingSlot(
              DateTime(now.year, now.month, now.day + 2, 16),
            ),
          ),
        ),
      ],
      if (scope == LeadScope.developer)
        (
          'project enquiry',
          (id) => Lead(
            id: id,
            kind: LeadKind.projectEnquiry,
            receivedAt: now,
            customerName: 'Sample customer',
            phone: '+968 9000 0003',
            message: 'Which units are still available?',
            projectId: 'pr1',
            projectName: 'Sample project',
          ),
        ),
      if (scope == LeadScope.service)
        (
          'service request',
          (id) => Lead(
            id: id,
            kind: LeadKind.serviceRequest,
            receivedAt: now,
            customerName: 'Sample customer',
            phone: '+968 9000 0004',
            message: 'We would like a quotation.',
            serviceCategory: ServiceCategory.construction,
            serviceLocation: 'Muscat',
            requestedTiming: 'Next month',
          ),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: Wrap(
        spacing: AQSpacing.x2,
        runSpacing: AQSpacing.x2,
        children: [
          for (final i in items)
            AQTextButton(
              label: f.t('ld.qa.add', {'k': i.$1}),
              onPressed: () => add(i.$2),
            ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ detail

class LeadDetailScreen extends ConsumerStatefulWidget {
  final LeadScope scope;
  final String id;
  const LeadDetailScreen({super.key, required this.scope, required this.id});
  @override
  ConsumerState<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends ConsumerState<LeadDetailScreen> {
  bool _busy = false;
  String? _errorKey, _doneKey;

  Future<void> _call(Lead l) async {
    setState(() => _errorKey = null);
    final ok = await ref.read(phoneLauncherProvider).dial(l.phone!);
    if (!ok && mounted) setState(() => _errorKey = 'ld.call.fail');
  }

  Future<void> _respond(Lead l, ViewingResponse r) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _errorKey = null;
      _doneKey = null;
    });
    try {
      await ref.read(leadRepositoryProvider).respondToViewing(l.id, r);
      ref.invalidate(leadProvider(l.id));
      ref.invalidate(leadsProvider(widget.scope));
      if (mounted) {
        setState(
          () => _doneKey = r == ViewingResponse.confirm
              ? 'ld.vw.done.confirm'
              : 'ld.vw.done.decline',
        );
      }
    } catch (_) {
      ref.invalidate(leadProvider(l.id));
      if (mounted) setState(() => _errorKey = 'ld.vw.err');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline(Lead l) async {
    final f = FlowStrings.of(context);
    final yes = await showAQSheet<bool>(
      context,
      useRootNavigator: true,
      builder: (s) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AQSpacing.gutter,
          AQSpacing.x2,
          AQSpacing.gutter,
          AQSpacing.x4,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                f.t('ld.vw.declineT'),
                style: AQTypography.of(s, AQText.headlineSmall),
              ),
            ),
            const SizedBox(height: AQSpacing.x2),
            Text(
              f.t('ld.vw.declineB'),
              style: AQTypography.of(s, AQText.bodyMedium, soft: true),
            ),
            const SizedBox(height: AQSpacing.x4),
            AQPrimaryButton(
              label: f.t('ld.vw.declineKeep'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(false),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ld.vw.declineYes'),
              trailingChevron: false,
              onPressed: () => Navigator.of(s).pop(true),
            ),
          ],
        ),
      ),
    );
    if (yes == true) await _respond(l, ViewingResponse.decline);
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final scope = widget.scope;
    final listRoute = _listRoute(scope);
    void back() => aqBack(context, listRoute);
    return LeadGuard(
      scope: scope,
      title: f.t('ld.d.title'),
      backFallback: listRoute,
      builder: (context) {
        final async = ref.watch(leadProvider(widget.id));
        return async.when(
          loading: () => AQViewingScaffold(
            title: f.t('ld.d.title'),
            backLabel: f.t('common.back'),
            onBack: back,
            children: const [
              AQViewingSkeleton(height: 120),
              AQViewingSkeleton(height: 160),
            ],
          ),
          error: (e, _) => AQViewingScaffold(
            title: f.t('ld.d.title'),
            backLabel: f.t('common.back'),
            onBack: back,
            bottom: e is PermissionDeniedException
                ? AQBottomActionBar(
                    primary: AQPrimaryButton(
                      label: f.t('ld.d.back'),
                      trailingChevron: false,
                      onPressed: back,
                    ),
                  )
                : null,
            children: [
              if (e is PermissionDeniedException)
                AQNoticeCard(
                  icon: 'lock',
                  title: f.t('ld.d.denied.t'),
                  body: f.t('ld.d.denied.b'),
                )
              else
                DbErrorCard(
                  error: e,
                  onRetry: () => ref.invalidate(leadProvider(widget.id)),
                ),
            ],
          ),
          data: (l) {
            if (l == null) {
              return AQViewingScaffold(
                title: f.t('ld.d.title'),
                backLabel: f.t('common.back'),
                onBack: back,
                bottom: AQBottomActionBar(
                  primary: AQPrimaryButton(
                    label: f.t('ld.d.back'),
                    trailingChevron: false,
                    onPressed: back,
                  ),
                ),
                children: [
                  AQNoticeCard(
                    icon: 'info',
                    title: f.t('ld.d.notFound'),
                    body: '',
                  ),
                ],
              );
            }
            Widget row(String k, String v) => Padding(
              padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
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
            final viewing =
                l.kind == LeadKind.viewingRequest && l.viewingStatus != null;
            final respond = l.canRespondToViewing;
            final image = _image(l);
            final openRoute =
                l.propertyId != null && l.kind != LeadKind.projectEnquiry
                ? '/property/${l.propertyId}'
                : (l.projectId != null
                      ? '/build/project/${l.projectId}'
                      : null);

            final callButton = l.hasPhone
                ? (respond
                      ? AQSecondaryButton(
                          label: f.t('ld.call'),
                          leadingIcon: 'phone',
                          trailingChevron: false,
                          onPressed: () => _call(l),
                        )
                      : AQPrimaryButton(
                          label: f.t('ld.call'),
                          leadingIcon: 'phone',
                          trailingChevron: false,
                          onPressed: () => _call(l),
                        ))
                : null;

            Widget? primary, secondary;
            if (respond) {
              primary = AQPrimaryButton(
                label: f.t('ld.vw.confirm'),
                trailingChevron: false,
                loading: _busy,
                onPressed: _busy
                    ? null
                    : () => _respond(l, ViewingResponse.confirm),
              );
              secondary = AQBarSecondaryButton(
                label: f.t('ld.vw.decline'),
                onPressed: _busy ? null : () => _decline(l),
              );
            } else if (callButton != null) {
              primary = callButton;
            }
            return AQViewingScaffold(
              title: VFmt.iso(_title(f, l)),
              subtitle: f.t('ld.kind.${l.kind.name}'),
              backLabel: f.t('common.back'),
              onBack: back,
              bottom: primary == null
                  ? null
                  : AQBottomActionBar(
                      primary: primary,
                      secondary: secondary,
                      footnote: l.hasPhone ? null : f.t('ld.call.none'),
                    ),
              children: [
                if (_doneKey != null)
                  AQErrorBanner(
                    tone: AQBannerTone.success,
                    text: f.t(_doneKey!),
                  ),
                if (_errorKey != null) AQErrorBanner(text: f.t(_errorKey!)),
                if (viewing) ...[
                  AQNoticeCard(
                    icon: _viewingLook(l.viewingStatus!).$2,
                    title: f.t('ld.vw.${l.viewingStatus!.name}'),
                    body: f.t('ld.vw.sum.${l.viewingStatus!.name}'),
                    tone: _viewingLook(l.viewingStatus!).$1,
                  ),
                  const SizedBox(height: AQSpacing.x3),
                ],
                // The property or project this request is about: its photograph first, then its name and the way in.
                AQSurface(
                  padding: EdgeInsets.zero,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AQRadius.medium),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: ExcludeSemantics(
                            child: image == null
                                ? ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon(_kindIcon(l.kind), size: 32, color: c.accent)))
                                : aqImg(image, cacheWidth: 800),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(AQSpacing.x4, AQSpacing.x3, AQSpacing.x3, AQSpacing.x2),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.t('ld.d.related'), style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
                              Text(VFmt.iso(_title(f, l)), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.headlineSmall)),
                              if (openRoute != null)
                                AQTextButton(
                                  label: l.kind == LeadKind.projectEnquiry ? f.t('ld.d.openProject') : f.t('ld.d.openProperty'),
                                  color: c.accent,
                                  onPressed: () => context.push(openRoute),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AQViewingSectionTitle(f.t('ld.d.customer')),
                AQSurface(
                  padding: const EdgeInsets.all(AQSpacing.x4),
                  child: Column(
                    children: [
                      row(
                        f.t('ld.d.customer'),
                        VFmt.iso(l.customerName ?? f.t('ld.card.noName')),
                      ),
                      if (l.hasPhone)
                        row(f.t('ld.d.phone'), VFmt.iso(l.phone!)),
                      row(
                        f.t('ld.d.received'),
                        '${VFmt.fullDate(context, l.receivedAt)} · ${VFmt.time(context, l.receivedAt)}',
                      ),
                      if (l.status != null) row(f.t('ld.d.status'), l.status!),
                      if (l.requestedSlot != null)
                        row(
                          f.t('ld.d.slot'),
                          VFmt.dateTime(context, l.requestedSlot!),
                        ),
                      if (l.serviceCategory != null)
                        row(f.t('ld.d.category'), l.serviceCategory!.label),
                      if (l.serviceLocation != null)
                        row(f.t('ld.d.location'), VFmt.iso(l.serviceLocation!)),
                      if (l.requestedTiming != null)
                        row(f.t('ld.d.timing'), VFmt.iso(l.requestedTiming!)),
                    ],
                  ),
                ),
                if (respond && callButton != null) ...[
                  const SizedBox(height: AQSpacing.x3),
                  callButton,
                ],
                AQViewingSectionTitle(f.t('ld.d.message')),
                l.message.isEmpty
                    ? DbNotice(f.t('ld.d.noMessage'))
                    : Text(
                        l.message,
                        style: AQTypography.of(context, AQText.bodyMedium),
                      ),
                const SizedBox(height: AQSpacing.x4),
                const AQDemoNotice(),
              ],
            );
          },
        );
      },
    );
  }
}
