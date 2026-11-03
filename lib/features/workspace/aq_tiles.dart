import 'package:flutter/material.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import 'aq_home.dart' show aqImg;

/// Columns for a grid of photographic tiles: two on any phone (never four tiny cards in a row),
/// three on a tablet, four on a wide screen.
int aqTileColumns(double width) => width >= 1000 ? 4 : (width >= 640 ? 3 : 2);

/// A photographic tile: a large picture, the name, one line of description and a tap indicator.
/// The same tile serves property categories, professional categories and services, so they read as
/// one family; only the picture and wording differ.
class AQPhotoTile extends StatelessWidget {
  final String image, icon, title, sub;
  final double aspect;
  final VoidCallback onTap;
  const AQPhotoTile({
    super.key,
    required this.image,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.aspect = 0.92,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    void tap() {
      AQHaptics.selection();
      onTap();
    }

    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: tap,
      child: AQPressable(
        onTap: tap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: AspectRatio(
            aspectRatio: aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: aqImg(image, cacheWidth: 640)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x00000000), Color(0x26000000), Color(0xCC000000)],
                      stops: [0.30, 0.58, 1],
                    ),
                  ),
                ),
                PositionedDirectional(
                  top: AQSpacing.x3,
                  start: AQSpacing.x3,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: AQGlass(radius: 18, blur: 0, fill: 0.34, shadow: false, child: Center(child: AQIcon(icon, size: 18, color: Colors.white))),
                  ),
                ),
                PositionedDirectional(
                  top: AQSpacing.x3,
                  end: AQSpacing.x3,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: AQGlass(radius: 16, blur: 0, fill: 0.82, shadow: false, child: Center(child: AQIcon('chevron-right', size: 16, color: c.ink, directional: true))),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(context, AQText.titleMedium, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(context, AQText.bodySmall, color: Colors.white.withValues(alpha: 0.88)),
                      ),
                    ],
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

/// A responsive grid of equal tiles. Large text keeps two columns but makes the tiles taller so
/// the words never clip.
class AQTileGrid extends StatelessWidget {
  final List<AQPhotoTile> tiles;
  const AQTileGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AQSpacing.x3;
        final cols = aqTileColumns(box.maxWidth);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final t in tiles)
              SizedBox(
                width: w,
                child: AQPhotoTile(image: t.image, icon: t.icon, title: t.title, sub: t.sub, onTap: t.onTap, aspect: large ? 0.72 : t.aspect),
              ),
          ],
        );
      },
    );
  }
}
