import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_documents.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'db_models.dart';
import 'db_repository.dart';
import 'db_widgets.dart';

/// Page frame for workspace screens that sit inside the customer shell (the four-tab nav stays,
/// Account is selected). Room is left at the bottom for the floating nav.
class DbShellPage extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> children;
  const DbShellPage({
    super.key,
    this.eyebrow,
    required this.title,
    this.subtitle,
    this.onBack,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AQSpacing.gutter,
              AQSpacing.x2,
              AQSpacing.gutter,
              128,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (onBack != null)
                  AQIconButton(
                    icon: 'chevron-left',
                    semanticsLabel: f.t('common.back'),
                    onPressed: onBack,
                  ),
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AQSpacing.x2),
                    child: Text(
                      eyebrow!,
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        color: c.accentDeep,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x1),
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AQTypography.of(context, AQText.headlineLarge),
                    ),
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AQSpacing.x2),
                    child: Text(
                      subtitle!,
                      style: AQTypography.of(
                        context,
                        AQText.bodyMedium,
                        soft: true,
                      ),
                    ),
                  ),
                const SizedBox(height: AQSpacing.x5),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a workspace screen: only an approved grant of the right type gets through. Everything
/// else becomes a calm, specific explanation with the next step. This improves UX only; the
/// repository re-checks ownership on every call.
class DbGuard extends ConsumerWidget {
  final bool developerOnly;
  final bool inShell;
  final String title;
  final String? eyebrow;
  final String backFallback;
  final Widget Function(BuildContext context, WorkspaceAccess access) builder;
  const DbGuard({
    super.key,
    this.developerOnly = false,
    this.inShell = true,
    required this.title,
    this.eyebrow,
    required this.backFallback,
    required this.builder,
  });

  Widget _frame(BuildContext context, List<Widget> children) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, backFallback);
    if (inShell)
      return DbShellPage(
        eyebrow: eyebrow,
        title: title,
        onBack: back,
        children: children,
      );
    return AQViewingScaffold(
      title: title,
      backLabel: f.t('common.back'),
      onBack: back,
      children: children,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final async = ref.watch(workspaceAccessProvider);
    return async.when(
      loading: () => _frame(context, const [DbSkeletonList()]),
      error: (e, _) => _frame(context, [
        DbErrorCard(
          error: e,
          onRetry: () => ref.invalidate(workspaceAccessProvider),
        ),
      ]),
      data: (a) {
        if (a.approved && (!developerOnly || a.type == ProType.developer))
          return builder(context, a);
        if (a.approved) {
          return _frame(context, [
            DbNotice(
              f.t('db.gate.devOnly'),
              icon: 'lock',
              action: AQTextButton(
                label: f.t('db.gate.toWorkspace'),
                color: AQColors.of(context).accent,
                onPressed: () => context.go('/app/account/workspace'),
              ),
            ),
          ]);
        }
        final children = switch (a.gate) {
          WorkspaceGate.signedOut => [
            DbNotice(f.t('db.gate.signedOut'), icon: 'user'),
            const SizedBox(height: AQSpacing.x3),
            AQPrimaryButton(
              label: f.t('guest.login'),
              trailingChevron: false,
              onPressed: () => context.push('/login'),
            ),
          ],
          WorkspaceGate.notBusiness => [
            DbNotice(f.t('db.gate.notBusiness'), icon: 'lock'),
          ],
          WorkspaceGate.onboarding => [
            DbNotice(f.t('db.gate.onboarding'), icon: 'info'),
            const SizedBox(height: AQSpacing.x3),
            AQPrimaryButton(
              label: f.t('db.gate.verify'),
              trailingChevron: false,
              onPressed: () => context.go('/verification'),
            ),
          ],
          _ => [
            if (a.grant != null)
              DbFit(AQStatusBadge(grant: a.grant!, stage: a.stage)),
            const SizedBox(height: AQSpacing.x3),
            DbNotice(
              f.t('db.gate.${a.gate.name}'),
              icon:
                  a.gate == WorkspaceGate.rejected ||
                      a.gate == WorkspaceGate.suspended
                  ? 'lock'
                  : 'clock',
            ),
            const SizedBox(height: AQSpacing.x3),
            AQPrimaryButton(
              label: f.t('home.viewStatus'),
              trailingChevron: false,
              onPressed: () => context.go('/verification'),
            ),
          ],
        };
        return _frame(context, children);
      },
    );
  }
}

// ------------------------------------------------------ #68 / #77 dashboard

class DbDashboardScreen extends ConsumerWidget {
  const DbDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    return DbGuard(
      title: f.t('db.ws.title'),
      eyebrow: f.t('db.ws.eyebrow'),
      backFallback: '/app/account',
      builder: (context, a) => DbShellPage(
        eyebrow: f.t('db.ws.eyebrow'),
        title: f.t('db.ws.title'),
        onBack: () => aqBack(context, '/app/account'),
        children: [_Dashboard(access: a)],
      ),
    );
  }
}

class _Dashboard extends ConsumerWidget {
  final WorkspaceAccess access;
  const _Dashboard({required this.access});

  Widget _tile(
    BuildContext context, {
    required String icon,
    required String label,
    String? sub,
    required VoidCallback onTap,
  }) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: sub == null ? label : '$label. $sub',
      excludeSemantics: true,
      onTap: () {
          AQHaptics.selection();
          onTap();
        },
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 84),
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.surfaceSelected,
                  shape: BoxShape.circle,
                ),
                child: Center(child: DbIcon(icon, size: 22, color: c.accent)),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    if (sub != null)
                      Text(
                        sub,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      ),
                  ],
                ),
              ),
              AQIcon(
                'chevron-right',
                size: 18,
                color: c.inkSoft,
                directional: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final type = access.type!;
    final org = ref.watch(dbMyOrgProvider);
    final repo = ref.watch(devBuildRepositoryProvider);
    final projects = type.hasProjects ? ref.watch(dbMyProjectsProvider) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity
        Container(
          padding: const EdgeInsets.all(AQSpacing.x4),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.large),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: c.surfaceSelected,
                  borderRadius: BorderRadius.circular(AQRadius.medium),
                ),
                child: Center(
                  child: AQIcon(type.icon, size: 28, color: c.accent),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: org.when(
                  loading: () => const DbSkeleton(height: 48),
                  error: (e, _) => Text(
                    f.t('common.networkError'),
                    style: AQTypography.of(
                      context,
                      AQText.bodySmall,
                      color: c.danger,
                    ),
                  ),
                  data: (o) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              VFmt.iso(o?.name ?? ''),
                              style: AQTypography.of(
                                context,
                                AQText.headlineSmall,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AQIcon('verified', size: 18, color: c.accent),
                        ],
                      ),
                      Text(
                        f.t(type.key),
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        DbFit(AQStatusBadge(grant: GrantState.approved)),
        // Project summary (developers): counts come from the returned projects, nothing else.
        if (projects != null) ...[
          DbSectionTitle(
            f.t('db.ws.projects'),
            action: f.t('pt.viewAll'),
            onAction: () => context.push('/app/account/workspace/projects'),
          ),
          projects.when(
            loading: () => const DbSkeleton(height: 96),
            error: (e, _) => DbErrorCard(
              error: e,
              onRetry: () => ref.invalidate(dbMyProjectsProvider),
            ),
            data: (list) {
              if (list.isEmpty)
                return DbNotice(f.t('db.ws.noProjects'), icon: 'development');
              int n(ProjectStatus s) => list.where((p) => p.status == s).length;
              final cells = [
                (f.t('db.ws.total'), list.length),
                (f.t(ProjectStatus.approved.key), n(ProjectStatus.approved)),
                (
                  f.t(ProjectStatus.underReview.key),
                  n(ProjectStatus.underReview),
                ),
                (f.t(ProjectStatus.draft.key), n(ProjectStatus.draft)),
                if (n(ProjectStatus.changesRequested) > 0)
                  (
                    f.t(ProjectStatus.changesRequested.key),
                    n(ProjectStatus.changesRequested),
                  ),
                if (n(ProjectStatus.rejected) > 0)
                  (f.t(ProjectStatus.rejected.key), n(ProjectStatus.rejected)),
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: AQSpacing.x2,
                    runSpacing: AQSpacing.x2,
                    children: [
                      for (final x in cells)
                        Container(
                          width: 104,
                          padding: const EdgeInsets.symmetric(
                            vertical: AQSpacing.x3,
                            horizontal: AQSpacing.x2,
                          ),
                          decoration: BoxDecoration(
                            color: c.surfaceRaised,
                            borderRadius: BorderRadius.circular(
                              AQRadius.medium,
                            ),
                            border: Border.all(color: c.hairline),
                          ),
                          child: Semantics(
                            label: '${x.$1}: ${x.$2}',
                            excludeSemantics: true,
                            child: Column(
                              children: [
                                Text(
                                  VFmt.n(context, x.$2),
                                  style: AQTypography.of(
                                    context,
                                    AQText.headlineMedium,
                                  ),
                                ),
                                Text(
                                  x.$1,
                                  textAlign: TextAlign.center,
                                  style: AQTypography.of(
                                    context,
                                    AQText.labelSmall,
                                    soft: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AQSpacing.x3),
                  for (final p in list.take(3))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                      child: DbProjectCard(
                        project: p,
                        showStatus: true,
                        onTap: () =>
                            context.push('/workspace/projects/${p.id}'),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: AQSpacing.x2),
          AQPrimaryButton(
            label: f.t('db.ws.add'),
            trailingChevron: false,
            leadingIcon: 'plus',
            onPressed: () => context.push('/workspace/projects/new'),
          ),
          const SizedBox(height: AQSpacing.x3),
          AQSecondaryButton(
            label: f.t('db.ws.manage'),
            trailingChevron: false,
            onPressed: () => context.push('/app/account/workspace/projects'),
          ),
        ],
        DbSectionTitle(f.t('db.ws.manageBiz')),
        _tile(
          context,
          icon: 'user',
          label: f.t('db.ws.profile'),
          sub: f.t('db.ws.profile.s'),
          onTap: () => context.push('/app/account/workspace/profile'),
        ),
        const SizedBox(height: AQSpacing.x2),
        _tile(
          context,
          icon: 'phone',
          label: f.t('db.ws.leads'),
          sub: repo.caps.leadEvents
              ? f.t('db.ws.leads.s')
              : f.t('db.unavailable'),
          onTap: () => context.push('/app/account/workspace/leads'),
        ),
        const SizedBox(height: AQSpacing.x2),
        _tile(
          context,
          icon: 'review',
          label: f.t('db.ws.reviews'),
          sub: f.t('db.ws.reviews.s'),
          onTap: () => context.push('/app/account/workspace/reviews'),
        ),
        const SizedBox(height: AQSpacing.x2),
        _tile(
          context,
          icon: 'handshake',
          label: f.t('db.ws.eng'),
          sub: repo.caps.engagements
              ? f.t('db.ws.eng.s')
              : f.t('db.unavailable'),
          onTap: () => context.push('/app/account/workspace/engagements'),
        ),
        if (!type.hasProjects) ...[
          const SizedBox(height: AQSpacing.x2),
          _tile(
            context,
            icon: 'work',
            label: f.t('db.ws.portfolio'),
            sub: f.t('db.ws.portfolio.s'),
            onTap: () => context.push('/app/account/workspace/portfolio'),
          ),
        ],
      ],
    );
  }
}
