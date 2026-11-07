import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart' show BusinessCategory;
import '../contact/contact_actions.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg;
import '../workspace/aq_thumb.dart' show AQThumb;
import 'aq_business_profile.dart' show aqBusinessProvider;
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// One project in a business's portfolio. There is no projects feed yet, so these are built from the
/// business's own photographs and category: sample records, clearly labelled as such.
class AQProject {
  final String id, name, place, status, blurb;
  final int year, sqm, months;
  final List<String> photos;
  final BusinessCategory category;
  const AQProject({
    required this.id,
    required this.name,
    required this.place,
    required this.status,
    required this.blurb,
    required this.year,
    required this.sqm,
    required this.months,
    required this.photos,
    required this.category,
  });
}

BusinessCategory _primary(Business b) => b.categories.firstWhere((c) => c != BusinessCategory.realEstateAgent, orElse: () => b.categories.isEmpty ? BusinessCategory.construction : b.categories.first);

/// Sample projects for a business: stable for the same business, three to five of them.
List<AQProject> aqProjectsFor(Business b, FlowStrings f) {
  final cat = _primary(b);
  final photos = b.galleryUrls;
  final n = photos.isEmpty ? 3 : photos.length.clamp(3, 5);
  final seed = b.id.codeUnits.fold<int>(11, (a, c) => (a * 31 + c) % 9973);
  final places = b.serviceArea.isNotEmpty ? b.serviceArea.split(RegExp(r'[,،]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : <String>[];
  final fallbackPlace = b.locationLabel;
  return [
    for (var i = 0; i < n; i++)
      AQProject(
        id: 'p$i',
        name: f.t('bp.pn.${cat.name}.${i % 3}'),
        place: places.isEmpty ? fallbackPlace : places[(i + seed) % places.length],
        status: i == 0 && cat != BusinessCategory.maintenance ? 'bp.pst.progress' : 'bp.pst.done',
        blurb: f.t('bp.pb.${cat.name}'),
        year: 2026 - ((seed + i * 2) % 5),
        sqm: 120 + ((seed * (i + 3)) % 18) * 25,
        months: 3 + ((seed + i * 5) % 12),
        photos: photos.isEmpty ? const [] : [for (var k = 0; k < (photos.length < 3 ? photos.length : 3); k++) photos[(i + k) % photos.length]],
        category: cat,
      ),
  ];
}

/// The Projects block of a business profile: large cards, each opening the full project.
class AQProjectsSection extends StatelessWidget {
  final Business business;
  const AQProjectsSection({super.key, required this.business});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final projects = aqProjectsFor(business, f);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final p in projects) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x4), child: _ProjectCard(business: business, project: p)),
      Text(f.t('bp.proj.sample'), style: AQTypography.of(context, AQText.labelMedium, color: AQColors.of(context).inkFaint)),
    ]);
  }
}

class _ProjectCard extends StatelessWidget {
  final Business business;
  final AQProject project;
  const _ProjectCard({required this.business, required this.project});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    void open() => context.push('/business/${business.id}/project/${project.id}');
    Widget fact(String icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
      AQIcon(icon, size: 15, color: c.accent),
      const SizedBox(width: 5),
      Text(text, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft).copyWith(letterSpacing: 0.1)),
    ]);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${project.name}. ${project.place}. ${f.t(project.status)}',
      excludeSemantics: true,
      onTap: open,
      child: AQPressable(
        onTap: open,
        child: AQGlass(
          radius: 26,
          blur: 10,
          fill: 0.7,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Stack(children: [
              AspectRatio(
                aspectRatio: 16 / 10,
                child: ExcludeSemantics(child: project.photos.isEmpty ? ColoredBox(color: c.surfaceSelected) : aqImg(project.photos.first, cacheWidth: 900)),
              ),
              PositionedDirectional(
                top: 12,
                start: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: c.surfaceRaised.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(14)),
                  child: Text(f.t(project.status), style: AQTypography.of(context, AQText.labelMedium, color: project.status == 'bp.pst.done' ? c.success : c.warning).copyWith(letterSpacing: 0.1)),
                ),
              ),
              if (project.photos.length > 1)
                PositionedDirectional(
                  bottom: 12,
                  end: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: const Color(0x99000000), borderRadius: BorderRadius.circular(14)),
                    child: Text('${project.photos.length} ${f.t('bp.proj.photos')}', style: AQTypography.of(context, AQText.labelMedium, color: Colors.white).copyWith(letterSpacing: 0.1)),
                  ),
                ),
            ]),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(project.name, style: AQTypography.of(context, AQText.titleMedium)),
                const SizedBox(height: 4),
                Row(children: [
                  AQIcon('pin', size: 15, color: c.accent),
                  const SizedBox(width: 5),
                  Flexible(child: Text(VFmt.iso(project.place), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  fact('calendar', '${project.year}'),
                  fact('area', '${project.sqm} ${f.t('bp.proj.sqm')}'),
                  fact('clock', f.t('bp.proj.months', {'n': '${project.months}'})),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A project in full: all its photographs, the facts, what was done and who did it.
class AQProjectDetailScreen extends ConsumerWidget {
  final String businessId, projectId;
  const AQProjectDetailScreen({super.key, required this.businessId, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(aqBusinessProvider(businessId));
    final b = async.valueOrNull;
    void back() => context.canPop() ? context.pop() : context.go('/business/$businessId');
    if (b == null) {
      return AQViewingScaffold(backLabel: f.t('common.back'), onBack: back, children: [
        Padding(padding: const EdgeInsets.only(top: 80), child: Center(child: async.isLoading ? const CircularProgressIndicator() : Text(f.t('bp.proj.missing')))),
      ]);
    }
    final all = aqProjectsFor(b, f);
    final p = all.where((x) => x.id == projectId).firstOrNull ?? all.first;
    Widget tile(String icon, String label, String value) => Expanded(
      child: AQGlass(
        radius: 20,
        blur: 8,
        fill: 0.66,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AQIcon(icon, size: 18, color: c.accent),
          const SizedBox(height: 8),
          Text(value, style: AQTypography.of(context, AQText.titleSmall)),
          const SizedBox(height: 2),
          Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        ]),
      ),
    );
    const gap = SizedBox(width: AQSpacing.x3);
    final scope = ['bp.scope.design', 'bp.scope.build', 'bp.scope.finish', 'bp.scope.handover'];
    return AQViewingScaffold(
      backLabel: f.t('common.back'),
      onBack: back,
      title: p.name,
      subtitle: '${VFmt.iso(b.name)} · ${VFmt.iso(p.place)}',
      children: [
        for (final (i, url) in p.photos.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: ClipRRect(borderRadius: BorderRadius.circular(AQRadius.large), child: AspectRatio(aspectRatio: i == 0 ? 16 / 10 : 16 / 9, child: ExcludeSemantics(child: aqImg(url, cacheWidth: 1000)))),
          ),
        if (p.photos.isEmpty) AspectRatio(aspectRatio: 16 / 10, child: ClipRRect(borderRadius: BorderRadius.circular(AQRadius.large), child: ColoredBox(color: c.surfaceSelected))),
        const SizedBox(height: AQSpacing.x2),
        Row(children: [tile('listings', f.t('bp.proj.type'), f.t('bcat.${p.category.name}')), gap, tile('calendar', f.t('bp.proj.year'), '${p.year}')]),
        const SizedBox(height: AQSpacing.x3),
        Row(children: [tile('area', f.t('bp.proj.size'), '${p.sqm} ${f.t('bp.proj.sqm')}'), gap, tile('clock', f.t('bp.proj.duration'), f.t('bp.proj.months', {'n': '${p.months}'}))]),
        const SizedBox(height: AQSpacing.x3),
        Row(children: [tile('verified', f.t('bp.proj.status'), f.t(p.status)), gap, tile('pin', f.t('bp.proj.location'), VFmt.iso(p.place))]),
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x2), child: Semantics(header: true, child: Text(f.t('bp.proj.about'), style: AQTypography.of(context, AQText.headlineSmall)))),
        Text(p.blurb, style: AQTypography.of(context, AQText.bodyMedium)),
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x2), child: Semantics(header: true, child: Text(f.t('bp.proj.scope'), style: AQTypography.of(context, AQText.headlineSmall)))),
        for (final k in scope)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [AQIcon('check', size: 18, color: c.success), const SizedBox(width: 10), Expanded(child: Text(f.t(k), style: AQTypography.of(context, AQText.bodyMedium)))]),
          ),
        Padding(padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3), child: Semantics(header: true, child: Text(f.t('bp.proj.by'), style: AQTypography.of(context, AQText.headlineSmall)))),
        AQGlass(
          radius: 24,
          blur: 10,
          fill: 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Semantics(
              button: true,
              label: b.name,
              excludeSemantics: true,
              onTap: () => context.push('/business/${b.id}'),
              child: AQPressable(
                onTap: () => context.push('/business/${b.id}'),
                child: Row(children: [
                  AQThumb(monogramOf: b.name, size: 48),
                  const SizedBox(width: 12),
                  Expanded(child: Text(VFmt.iso(b.name), style: AQTypography.of(context, AQText.titleSmall))),
                  AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
                ]),
              ),
            ),
            const SizedBox(height: AQSpacing.x3),
            AQContactButtons(name: b.name, phone: aqDemoPhoneFor(b.id), subject: p.name),
          ]),
        ),
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('bp.proj.sample'), style: AQTypography.of(context, AQText.labelMedium, color: c.inkFaint)),
        const SizedBox(height: AQSpacing.x6),
      ],
    );
  }
}
