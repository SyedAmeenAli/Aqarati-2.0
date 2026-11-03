import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../viewing/widgets/viewing_format.dart' show aqLargeText;
import 'aq_home.dart' show aqImg;

/// The six services on Home: Properties as the lead card, four photographic tiles, and the loan
/// calculator as a compact row. Nothing else lives on Home.
class AQHomeServices extends StatelessWidget {
  const AQHomeServices({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final large = aqLargeText(context);
    final wide = MediaQuery.sizeOf(context).width >= 720;
    const gap = AQSpacing.x3;

    Widget photo(String key, String icon, String image, String path, {double aspect = 0.92, bool lead = false}) {
      final title = f.t('hm7.$key');
      final sub = f.t('hm7.$key.s');
      return _PhotoTile(
        icon: icon,
        image: image,
        title: title,
        sub: sub,
        aspect: aspect,
        lead: lead,
        onTap: () => context.push(path),
      );
    }

    final lead = photo(
      'properties',
      'home',
      'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
      '/properties',
      aspect: large ? 1.4 : (wide ? 3.4 : 2.1),
      lead: true,
    );
    final tiles = [
      photo('development', 'development', 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg', '/app/explore/build/results?cat=developer'),
      photo('interior', 'interior', 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg', '/app/explore/build/results?cat=interiorExterior'),
      photo('construction', 'construction', 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg', '/app/explore/build/results?cat=construction'),
      photo('maintenance', 'shield', 'assets/businesses/b4/03_Plumbing_maintenance_under_sink.jpg', '/professionals?cat=maintenance'),
    ];
    final loan = _RowTile(
      icon: 'area',
      title: f.t('hm7.loan'),
      sub: f.t('hm7.loan.s'),
      onTap: () => context.push('/calculators'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        lead,
        const SizedBox(height: gap),
        if (large)
          for (final t in tiles) ...[t, const SizedBox(height: gap)]
        else if (wide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: gap),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
          const SizedBox(height: gap),
        ] else
          for (var i = 0; i < tiles.length; i += 2) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: tiles[i]),
                const SizedBox(width: gap),
                Expanded(child: tiles[i + 1]),
              ],
            ),
            const SizedBox(height: gap),
          ],
        loan,
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  final String icon, image, title, sub;
  final double aspect;
  final bool lead;
  final VoidCallback onTap;
  const _PhotoTile({
    required this.icon,
    required this.image,
    required this.title,
    required this.sub,
    required this.aspect,
    required this.onTap,
    this.lead = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: aqImg(image, cacheWidth: lead ? 900 : 500)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x33000000), Color(0xCC000000)],
                      stops: [0.3, 0.6, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  start: AQSpacing.x3,
                  top: AQSpacing.x3,
                  child: AQGlass(
                    radius: 18,
                    blur: 0,
                    opaque: true,
                    shadow: false,
                    child: SizedBox(width: 36, height: 36, child: Center(child: AQIcon(icon, size: 18, color: c.accentDeep))),
                  ),
                ),
                PositionedDirectional(
                  start: AQSpacing.x3,
                  end: AQSpacing.x3,
                  bottom: AQSpacing.x3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: lead ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(context, lead ? AQText.headlineSmall : AQText.titleSmall, color: Colors.white),
                      ),
                      if (lead) ...[
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AQTypography.of(context, AQText.bodySmall, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ],
                  ),
                ),
                if (lead)
                  PositionedDirectional(
                    end: AQSpacing.x3,
                    bottom: AQSpacing.x3,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                      child: Center(child: AQIcon('chevron-right', size: 16, color: c.onAccent, directional: true)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  final String icon, title, sub;
  final VoidCallback onTap;
  const _RowTile({required this.icon, required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x3),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle),
                child: Center(child: AQIcon(icon, size: 20, color: c.accent)),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AQTypography.of(context, AQText.titleSmall)),
                    Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  ],
                ),
              ),
              AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
            ],
          ),
        ),
      ),
    );
  }
}
