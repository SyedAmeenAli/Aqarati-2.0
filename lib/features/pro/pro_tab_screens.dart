import 'package:flutter/material.dart';
import '../workspace/aq_cards.dart' show AQPhotoTag;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/config/demo_mode.dart' show kDemoMode;
import '../../data/models/enums.dart' show PropertyType;
import '../workspace/aq_home.dart' show aqImg;
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/domain/account_models.dart' show InteriorExteriorServiceType;
import '../devbuild/db_models.dart';
import '../devbuild/db_workspace.dart' show DbShellPage;
import '../role_home/role_home_model.dart';
import '../search/aq_filter_sheet.dart' show AQChoicePill;
import '../settings/business_settings_screen.dart';
import '../viewing/widgets/viewing_format.dart';

/// Local, deterministic fixtures for the destinations a role has that no repository serves yet.
/// They are labelled "Sample data" on screen and never presented as measured or published.
const _sampleUnits = <(String project, String type, int total, int available, int reserved)>[
  ('Al Mouj Residences', 'pn.u.villa', 12, 5, 3),
  ('Namaa Courtyard Homes', 'pn.u.townhouse', 18, 9, 4),
  ('Barka Gardens', 'pn.u.apartment', 40, 22, 8),
];

/// The picture of each sample project and unit block. The unit blocks are the developer's own
/// approved projects, so they use the same pictures as everywhere else those projects appear.
String? _unitPhoto(String project) => switch (project) {
  'Al Mouj Residences' => DbProject.demoCoverFor('demo-p1', PropertyType.villa),
  'Namaa Courtyard Homes' => DbProject.demoCoverFor('demo-p2', PropertyType.townhouse),
  'Barka Gardens' => DbProject.demoCoverFor('demo-p3', PropertyType.apartment),
  _ => null,
};

const _projectPhotos = <String, String>{
  'Villa shell and finishing': 'assets/businesses/b2/02_Concrete_structural_construction.jpg',
  'Warehouse extension': 'assets/businesses/b2/04_Construction_site_structure_in_M.jpg',
  'Courtyard house': 'assets/properties/p4/06_Courtyard_villa_architecture_design.jpg',
  'Family villa concept': 'assets/businesses/b1/03_Architectural_model_of_contempor.jpg',
  'Boutique office design': 'assets/businesses/b1/13_30_Modern_office_lobby_interior.jpg',
  'Courtyard residence permit set': 'assets/businesses/b1/06_Courtyard_architectural_design_c.jpg',
};

/// A square photograph at the start of a project or unit-block row. Nothing is drawn in a real build,
/// where these fixtures have no pictures.
// ignore: unused_element
Widget _rowThumb(String? asset) {
  if (asset == null || !kDemoMode) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: AQSpacing.x3),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AQRadius.medium),
      child: SizedBox(width: 64, height: 64, child: ExcludeSemantics(child: aqImg(asset, cacheWidth: 200))),
    ),
  );
}

/// Stage keys: 0 planning, 1 in progress, 2 handover.
const _sampleProjects = <HomeRole, List<(String name, String place, int stage, int pct)>>{
  HomeRole.construction: [
    ('Villa shell and finishing', 'Al Mouj, Muscat', 1, 62),
    ('Warehouse extension', 'Sohar', 1, 35),
    ('Courtyard house', 'Bawshar, Muscat', 2, 96),
  ],
  HomeRole.architecture: [
    ('Family villa concept', 'Seeb, Muscat', 0, 20),
    ('Boutique office design', 'Qurum, Muscat', 1, 70),
    ('Courtyard residence permit set', 'Nizwa', 2, 100),
  ],
};

/// A project or inventory block as a photograph-led card: the picture (demo builds only, where these fixtures
/// have one) with a label on it, then the name and place, then [footer]. Same data as the old row.
class _ProPhotoCard extends StatelessWidget {
  final String semanticsLabel;
  final String? photo;
  final String? tag;
  final String title, place;
  final Widget footer;
  const _ProPhotoCard({required this.semanticsLabel, required this.photo, this.tag, required this.title, required this.place, required this.footer});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final showPhoto = photo != null && kDemoMode;
    return Semantics(
      container: true,
      label: semanticsLabel,
      child: Container(
        margin: const EdgeInsets.only(bottom: AQSpacing.x3),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline), boxShadow: AQElevation.subtle),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showPhoto)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    ExcludeSemantics(child: aqImg(photo!, cacheWidth: 800)),
                    if (tag != null) PositionedDirectional(start: AQSpacing.x3, top: AQSpacing.x3, child: AQPhotoTag(tag!)),
                  ]),
                ),
              Padding(
                padding: const EdgeInsets.all(AQSpacing.x4),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (!showPhoto && tag != null) ...[AQPhotoTag(tag!), const SizedBox(height: AQSpacing.x2)],
                  Text(VFmt.iso(title), style: AQTypography.of(context, AQText.headlineSmall)),
                  const SizedBox(height: 2),
                  if (place.isNotEmpty) Text(VFmt.iso(place), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  const SizedBox(height: AQSpacing.x3),
                  SizedBox(width: double.infinity, child: footer),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _ProPageCard extends StatelessWidget {
  final List<Widget> rows;
  const _ProPageCard({required this.rows});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline, indent: AQSpacing.x4, endIndent: AQSpacing.x4),
            rows[i],
          ],
        ],
      ),
    );
  }
}

Widget _sampleNote(BuildContext context, FlowStrings f) {
  final c = AQColors.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: AQSpacing.x3),
    child: Text(f.t('pn.sample'), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
  );
}

/// `/pro/units`: the development company's inventory by project and unit type.
class ProUnitsScreen extends StatelessWidget {
  const ProUnitsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final total = _sampleUnits.fold<int>(0, (a, u) => a + u.$3);
    final avail = _sampleUnits.fold<int>(0, (a, u) => a + u.$4);
    final reserved = _sampleUnits.fold<int>(0, (a, u) => a + u.$5);
    Widget stat(String label, int v) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(AQSpacing.x3),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(VFmt.n(context, v), style: AQTypography.of(context, AQText.headlineSmall)),
          Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true), maxLines: 2),
        ]),
      ),
    );
    return DbShellPage(
      eyebrow: f.t('pn.units'),
      title: f.t('pn.u.title'),
      subtitle: f.t('pn.u.sub'),
      children: [
        Row(children: [
          stat(f.t('pn.u.total'), total),
          const SizedBox(width: AQSpacing.x2),
          stat(f.t('pn.u.available'), avail),
          const SizedBox(width: AQSpacing.x2),
          stat(f.t('pn.u.reserved'), reserved),
        ]),
        const SizedBox(height: AQSpacing.x4),
        for (final u in _sampleUnits)
          _ProPhotoCard(
            semanticsLabel: '${u.$1}. ${f.t(u.$2)}. ${f.t('pn.u.total')} ${u.$3}, ${f.t('pn.u.available')} ${u.$4}, ${f.t('pn.u.reserved')} ${u.$5}',
            photo: _unitPhoto(u.$1),
            tag: f.t(u.$2),
            title: u.$1,
            place: f.t('pn.u.line', {'t': VFmt.n(context, u.$3), 'a': VFmt.n(context, u.$4), 'r': VFmt.n(context, u.$5)}),
            // Available, reserved and the rest (sold) of this project's stock, to scale.
            footer: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 8,
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: u.$4, child: ColoredBox(color: c.accent)),
                  Expanded(flex: u.$5, child: ColoredBox(color: c.warning)),
                  Expanded(flex: (u.$3 - u.$4 - u.$5).clamp(1, 9999), child: ColoredBox(color: c.hairline)),
                ]),
              ),
            ),
          ),
        _sampleNote(context, f),
      ],
    );
  }
}

/// `/pro/projects`: active projects of a construction company or architecture studio.
class ProProjectsScreen extends ConsumerWidget {
  const ProProjectsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final role = ref.watch(homeResolutionProvider).role;
    final rows = _sampleProjects[role] ?? _sampleProjects[HomeRole.construction]!;
    return DbShellPage(
      eyebrow: f.t('pn.projects'),
      title: f.t(role == HomeRole.architecture ? 'pn.pr.title.arch' : 'pn.pr.title'),
      subtitle: f.t('pn.pr.sub'),
      children: [
        for (final p in rows)
          _ProPhotoCard(
            semanticsLabel: '${p.$1}. ${p.$2}. ${f.t('pn.stage.${p.$3}')}, ${VFmt.n(context, p.$4)}%',
            photo: _projectPhotos[p.$1],
            tag: f.t('pn.stage.${p.$3}'),
            title: p.$1,
            place: p.$2,
            footer: Row(children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: TweenAnimationBuilder<double>(
                    // The bar fills to the project's own figure once when the page opens.
                    tween: Tween(begin: 0, end: p.$4 / 100),
                    duration: AQMotion.scaled(context, AQMotion.slow),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: c.hairline, color: c.accent),
                  ),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              Text('${VFmt.n(context, p.$4)}%', style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)),
            ]),
          ),
        _sampleNote(context, f),
      ],
    );
  }
}

/// `/pro/services`: the business's primary service and its additional services, all on the one
/// account, and the Explore categories they make it appear in.
class ProServicesScreen extends ConsumerWidget {
  const ProServicesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final role = ref.watch(homeResolutionProvider).role;
    final profile = ref.watch(businessProfileProvider);
    final primary = primaryServiceOf(role);
    final primaryType = switch (role) {
      HomeRole.developer => ProType.developer,
      HomeRole.construction => ProType.construction,
      HomeRole.architecture => ProType.architecture,
      HomeRole.interiorExterior => ProType.interiorExterior,
      _ => null,
    };
    final extra = proTypesOfServices(profile.services, primary: primaryType);
    final cats = <String>[
      if (primaryType != null) f.t(primaryType.key),
      for (final t in extra.types)
        if (t == ProType.interiorExterior)
          switch (extra.design) {
            InteriorExteriorServiceType.interior => f.t('st.svc.interior'),
            InteriorExteriorServiceType.exterior => f.t('st.svc.exterior'),
            _ => f.t(t.key),
          }
        else
          f.t(t.key),
    ];
    return DbShellPage(
      eyebrow: f.t('pn.services'),
      title: f.t('pn.sv.title'),
      subtitle: f.t('pn.sv.sub'),
      children: [
        Text(f.t('st.bz.primary'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
        const SizedBox(height: AQSpacing.x2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(18)),
          child: Text(f.t('st.svc.$primary'), style: AQTypography.of(context, AQText.labelMedium, color: c.onAccent)),
        ),
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('st.bz.services'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
        const SizedBox(height: AQSpacing.x2),
        Wrap(
          spacing: AQSpacing.x2,
          runSpacing: AQSpacing.x2,
          children: [
            for (final k in kServiceKeys)
              if (k != primary)
                AQChoicePill(label: f.t('st.svc.$k'), selected: profile.services.contains(k), onTap: () => ref.read(businessProfileProvider.notifier).toggleService(k)),
          ],
        ),
        const SizedBox(height: AQSpacing.x4),
        Text(f.t('pn.sv.explore'), style: AQTypography.of(context, AQText.labelMedium, soft: true)),
        const SizedBox(height: AQSpacing.x2),
        Wrap(
          key: const ValueKey('pro-explore-categories'),
          spacing: AQSpacing.x2,
          runSpacing: AQSpacing.x2,
          children: [
            for (final label in cats)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(16)),
                child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)),
              ),
          ],
        ),
        const SizedBox(height: AQSpacing.x2),
        Text(f.t('pn.sv.note'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        const SizedBox(height: AQSpacing.x4),
        AQSecondaryButton(label: f.t('st.bz.link'), trailingChevron: false, onPressed: () => context.push('/pro/settings')),
      ],
    );
  }
}
