import 'package:flutter/material.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import 'aq_home.dart' show aqImg;
import '../viewing/widgets/viewing_format.dart' show aqLargeText;

/// A photo card for a primary action: image on top, icon + title, one short line below.
/// Cards in [AQActionGrid] are always the same size.
class AQActionCard extends StatelessWidget {
  final String icon, image, title, sub;
  final VoidCallback onTap;
  const AQActionCard({
    super.key,
    required this.icon,
    required this.image,
    required this.title,
    required this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      label: '$title. $sub',
      excludeSemantics: true,
      focusable: true,
      onFocus: () {},
      onTap: onTap,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium - 1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 1.6,
                  child: ExcludeSemantics(child: aqImg(image, cacheWidth: 400)),
                ),
                Padding(
                  padding: const EdgeInsets.all(AQSpacing.x3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ConstrainedBox(
                        // Two lines are always reserved, so a one-line title never makes its card
                        // shorter than a card whose title wraps.
                        constraints: const BoxConstraints(minHeight: 40),
                        child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AQIcon(icon, size: 18, color: c.accent),
                          const SizedBox(width: AQSpacing.x2),
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AQTypography.of(
                                context,
                                AQText.titleSmall,
                              ),
                            ),
                          ),
                        ],
                      ),
                      ),
                      const SizedBox(height: AQSpacing.x1),
                      Text(
                        sub,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
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

/// Lays [cards] out two to a row. Each row is as tall as its tallest card and every card
/// stretches to it, so no card is ever smaller than its neighbour. One column at large text.
class AQActionGrid extends StatelessWidget {
  final List<Widget> cards;
  const AQActionGrid({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    const gap = AQSpacing.x3;
    if (aqLargeText(context)) {
      return Column(
        children: [
          for (final c in cards) ...[c, const SizedBox(height: gap)],
        ],
      );
    }
    return Column(
      children: [
        for (var i = 0; i < cards.length; i += 2) ...[
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: cards[i]),
                const SizedBox(width: gap),
                Expanded(
                  child: i + 1 < cards.length ? cards[i + 1] : const SizedBox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: gap),
        ],
      ],
    );
  }
}
