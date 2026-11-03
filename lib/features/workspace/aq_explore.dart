import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../role_home/mode_switch.dart';
import '../role_home/role_home_model.dart';
import '../role_home/role_home_widgets.dart' show RoleWorkspaceSwitcher;
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../search/aq_filters.dart';
import '../search/browse_taxonomy.dart';
import 'aq_home.dart';
import 'aq_tiles.dart';

/// Explore is a directory of what AQARATI offers: each area has its own banner and
/// a row of shortcuts, in contrast to Home's featured listings.
class AQExploreScreen extends ConsumerWidget {
  const AQExploreScreen({super.key});

  Widget _pill(BuildContext context, String label, VoidCallback onTap) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.hairline)),
          child: Center(widthFactor: 1, child: Text(label, style: AQTypography.of(context, AQText.labelMedium))),
        ),
      ),
    );
  }

  /// One market with every property type it holds, each opening its own results. Each market is its own
  /// card with a heading and an icon, so the chips read as belonging to it and wrap cleanly.
  Widget _typeRow(BuildContext context, FlowStrings f, PropCategory cat, void Function(String) go) {
    final c = AQColors.of(context);
    final icon = switch (cat) {
      PropCategory.residential => 'home',
      PropCategory.commercial => 'development',
      PropCategory.agriculture => 'globe',
      PropCategory.industrial => 'construction',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
      child: Container(
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
                child: Center(child: AQIcon(icon, size: 16, color: c.accent)),
              ),
              const SizedBox(width: AQSpacing.x2),
              Expanded(child: Semantics(header: true, child: Text(f.t(cat.key), style: AQTypography.of(context, AQText.titleSmall)))),
            ]),
            const SizedBox(height: AQSpacing.x3),
            Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
              for (final e in kBrowseTypes[cat]!)
                _pill(context, f.t('bt.${e.$1.name}'), () => go('/properties/all?cat=${cat.name}&types=${e.$1.name}')),
            ]),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    void go(String path) => context.push(path);
    return aqPage(
      context,
      hero: AQHero(
        image: 'assets/location/13_Old_Muscat_architectural_view.jpg',
        eyebrow: f.t('explore.eyebrow'),
        title: f.t('explore.hero'),
        sub: f.t('explore.hero.sub'),
        belowHeader: hasWorkSide(ref.watch(homeResolutionProvider))
            ? Padding(
                padding: const EdgeInsets.only(top: AQSpacing.x3),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: RoleWorkspaceSwitcher(selected: HomeWorkspace.buyer, onChanged: (w) => w == HomeWorkspace.agent ? switchToWork(context, ref) : null),
                ),
              )
            : null,
      ),
      children: [
        AQSearchEntry(hint: f.t('home.search.hint')),
        const SizedBox(height: AQSpacing.x5),
        AQBanner(
          image: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
          eyebrow: f.t('ex.props.eyebrow'),
          title: f.t('ex.props.t'),
          body: f.t('ex.props.b'),
          cta: f.t('ex.props.cta'),
          onTap: () => go('/properties/all'),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQTileGrid(tiles: [
          AQPhotoTile(image: PropCategory.residential.image, icon: 'home', title: f.t('cat.residential'), sub: f.t('ex.cat.residential.s'), onTap: () => go('/properties?cat=residential')),
          AQPhotoTile(image: PropCategory.commercial.image, icon: 'development', title: f.t('cat.commercial'), sub: f.t('ex.cat.commercial.s'), onTap: () => go('/properties?cat=commercial')),
          AQPhotoTile(image: PropCategory.agriculture.image, icon: 'globe', title: f.t('cat.agriculture'), sub: f.t('ex.cat.agriculture.s'), onTap: () => go('/properties?cat=agriculture')),
          AQPhotoTile(image: PropCategory.industrial.image, icon: 'construction', title: f.t('cat.industrial'), sub: f.t('ex.cat.industrial.s'), onTap: () => go('/properties?cat=industrial')),
        ]),
        const SizedBox(height: AQSpacing.x4),
        Semantics(header: true, child: Text(f.t('ex.types.t'), style: AQTypography.of(context, AQText.titleMedium))),
        const SizedBox(height: AQSpacing.x2),
        for (final cat in PropCategory.values) _typeRow(context, f, cat, go),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
          eyebrow: f.t('ex.dev.eyebrow'),
          title: f.t('ex.dev.t'),
          body: f.t('ex.dev.b'),
          cta: f.t('ex.dev.cta'),
          onTap: () => go('/app/explore/build'),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQTileGrid(tiles: [
          AQPhotoTile(image: 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg', icon: 'development', title: f.t('pro.developers'), sub: f.t('ex.pro.developer.s'), onTap: () => go('/app/explore/build/results?cat=developer')),
          AQPhotoTile(image: 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg', icon: 'construction', title: f.t('pro.construction'), sub: f.t('ex.pro.construction.s'), onTap: () => go('/app/explore/build/results?cat=construction')),
          AQPhotoTile(image: 'assets/businesses/b1/08_Doubleheight_atrium_architectur.jpg', icon: 'architecture', title: f.t('pro.architecture'), sub: f.t('ex.pro.architecture.s'), onTap: () => go('/app/explore/build/results?cat=architecture')),
          AQPhotoTile(image: 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg', icon: 'interior', title: f.t('pro.interior'), sub: f.t('ex.pro.interior.s'), onTap: () => go('/app/explore/build/results?cat=interiorExterior')),
        ]),
        const SizedBox(height: AQSpacing.x6),
        Semantics(header: true, child: Text(f.t('ex.people.t'), style: AQTypography.of(context, AQText.titleMedium))),
        const SizedBox(height: AQSpacing.x2),
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
          _pill(context, f.t('ex.people.agents'), () => go('/broker/list')),
          _pill(context, f.t('ex.people.trusted'), () => go('/broker')),
          _pill(context, f.t('pro.architecture'), () => go('/app/explore/build/results?cat=architecture')),
          _pill(context, f.t('pro.interior'), () => go('/app/explore/build/results?cat=interiorExterior')),
          _pill(context, f.t('pro.construction'), () => go('/app/explore/build/results?cat=construction')),
          _pill(context, f.t('home.maint'), () => go('/professionals?cat=maintenance')),
        ]),
        const SizedBox(height: AQSpacing.x4),
        AQBanner(
          image: 'assets/location/10_Muscat_corniche_at_warm_evening.jpg',
          eyebrow: f.t('ex.broker.eyebrow'),
          title: f.t('ex.broker.t'),
          body: f.t('ex.broker.b'),
          cta: f.t('ex.broker.cta'),
          onTap: () => go('/broker'),
        ),
        AQSectionHeader(f.t('home.maint'), sub: f.t('ex.maint.sub'), action: f.t('explore.exploreAll'), onAction: () => go('/professionals?cat=maintenance')),
        AQTileGrid(tiles: [
          AQPhotoTile(image: 'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg', icon: 'wrench', title: f.t('maint.plumber'), sub: f.t('ex.svc.plumber.s'), onTap: () => go('/professionals?cat=maintenance')),
          AQPhotoTile(image: 'assets/properties/p1/27_39_Private_pool_closeup_photography.jpg', icon: 'sunrise', title: f.t('maint.pool'), sub: f.t('ex.svc.pool.s'), onTap: () => go('/professionals?cat=maintenance')),
          AQPhotoTile(image: 'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg', icon: 'sun', title: f.t('maint.ac'), sub: f.t('ex.svc.ac.s'), onTap: () => go('/professionals?cat=maintenance')),
          AQPhotoTile(image: 'assets/properties/p1/16_Contemporary_kitchen_interior_ar.jpg', icon: 'home', title: f.t('maint.kitchen'), sub: f.t('ex.svc.kitchen.s'), onTap: () => go('/professionals?cat=maintenance')),
        ]),
        const SizedBox(height: AQSpacing.x6),
        AQBanner(
          image: 'assets/properties/p5/03_Contemporary_apartment_property_.jpg',
          eyebrow: f.t('ex.loan.eyebrow'),
          title: f.t('ex.loan.t'),
          body: f.t('ex.loan.b'),
          cta: f.t('ex.loan.cta'),
          onTap: () => go('/calculators'),
        ),
      ],
    );
  }
}
