import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_models.dart';
import '../devbuild/db_repository.dart';
import '../devbuild/db_widgets.dart' show DbErrorCard, DbNotice, DbProjectCard, DbSkeleton, dbTypeImage;
import 'role_home_model.dart';
import 'role_home_widgets.dart';
import '../ads/ad_models.dart' show AdAudience;
import '../ads/sponsored_banner.dart';
import '../analytics/analytics_screens.dart' show RoleKpiStrip;

/// Property Development: project-first and cinematic. A panoramic hero carries the two project
/// actions, then a pipeline of the developer's OWN projects filtered by the status the server
/// returned. Counts come from the returned records only; "published" means approved, never
/// merely submitted. Only an approved developer organisation reaches this screen.
class DeveloperHome extends ConsumerStatefulWidget {
  const DeveloperHome({super.key});
  @override
  ConsumerState<DeveloperHome> createState() => _DeveloperHomeState();
}

class _DeveloperHomeState extends ConsumerState<DeveloperHome> {
  ProjectStatus? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final accent = roleAccent(context, HomeRole.developer);
    final org = ref.watch(dbMyOrgProvider);
    final projects = ref.watch(dbMyProjectsProvider);
    final name = org.valueOrNull?.name ?? '';

    return RoleHomePage(children: [
      const RoleReveal(child: RoleHeader()),
      RoleReveal(
        index: 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RoleEyebrow(f.t('rh.dev.eyebrow'), color: accent),
          const SizedBox(height: AQSpacing.x1),
          Text(name.isNotEmpty ? name : f.t('rh.dev.sub'), style: AQTypography.of(context, AQText.titleMedium, soft: true)),
        ]),
      ),
      const SizedBox(height: AQSpacing.x3),
      RoleReveal(
        index: 2,
        child: RolePhotoPanel(
          image: dbTypeImage(ProType.developer),
          kicker: f.t('rh.dev.hero.k'),
          title: f.t('rh.dev.hero'),
          aspect: 1.5,
          alignment: Alignment.topCenter,
          actions: [
            RolePhotoButton(label: f.t('rh.dev.add'), icon: 'plus', onTap: () => context.push('/workspace/projects/new')),
            RolePhotoButton(label: f.t('rh.dev.manage'), onTap: () => context.push('/app/account/workspace/projects')),
          ],
        ),
      ),
      const SponsoredBannerSlot(audience: AdAudience.developer),
      const RoleKpiStrip(role: HomeRole.developer),
      RoleSection(f.t('rh.dev.pipeline'), action: f.t('pt.viewAll'), onAction: () => context.push('/app/account/workspace/projects'), accent: accent),
      projects.when(
        loading: () => const Column(children: [DbSkeleton(height: 44), SizedBox(height: AQSpacing.x3), DbSkeleton(height: 110)]),
        error: (e, _) => DbErrorCard(error: e, onRetry: () => ref.invalidate(dbMyProjectsProvider)),
        data: (list) {
          if (list.isEmpty) {
            return DbNotice(f.t('rh.dev.empty'), icon: 'development', action: AQTextButton(label: f.t('rh.dev.add'), color: c.accent, onPressed: () => context.push('/workspace/projects/new')));
          }
          int count(ProjectStatus? s) => s == null ? list.length : list.where((p) => p.status == s).length;
          // Always show All, Draft, Under review and Published; show the others only when they exist.
          final states = <ProjectStatus?>[
            null,
            ProjectStatus.draft,
            ProjectStatus.underReview,
            if (count(ProjectStatus.changesRequested) > 0) ProjectStatus.changesRequested,
            ProjectStatus.approved,
            if (count(ProjectStatus.rejected) > 0) ProjectStatus.rejected,
          ];
          final selected = states.contains(_filter) ? _filter : null;
          final shown = selected == null ? list : [for (final p in list) if (p.status == selected) p];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                for (final s in states)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: AQSpacing.x2),
                    child: _FilterChip(
                      label: '${s == null ? f.t('rh.dev.filter.all') : f.t(s.key)} · ${count(s)}',
                      selected: selected == s,
                      accent: accent,
                      onTap: () => setState(() => _filter = s),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: AQSpacing.x3),
            AnimatedSwitcher(
              duration: AQMotion.scaled(context, const Duration(milliseconds: 200)),
              child: KeyedSubtree(
                key: ValueKey(selected),
                child: shown.isEmpty
                    ? DbNotice(f.t('rh.dev.emptyFilter'), icon: 'info')
                    : Column(children: [
                        for (final p in shown)
                          Padding(
                            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                            child: DbProjectCard(project: p, showStatus: true, onTap: () => context.push('/workspace/projects/${p.id}')),
                          ),
                      ]),
              ),
            ),
            Text(f.t('rh.dev.ownerOnly'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint)),
          ]);
        },
      ),
      RoleSection(f.t('rh.leads.dev'), accent: accent),
      RoleRow(label: f.t('rh.leads.dev'), value: f.t('rh.view'), onTap: () => context.push('/workspace/enquiries')),
    ]);
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: selected,
      label: label,
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
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, const Duration(milliseconds: 180)),
          constraints: const BoxConstraints(minHeight: AQControl.tap),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.16) : c.surfaceRaised,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? accent : c.hairline, width: selected ? 1.5 : 1),
          ),
          child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: selected ? accent : c.inkSoft)),
        ),
      ),
    );
  }
}
