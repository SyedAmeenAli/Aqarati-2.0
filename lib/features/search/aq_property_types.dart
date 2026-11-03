
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_home.dart';
import 'browse_taxonomy.dart';

String _catIcon(PropCategory k) => switch (k) {
  PropCategory.residential => 'home',
  PropCategory.commercial => 'development',
  PropCategory.agriculture => 'globe',
  PropCategory.industrial => 'construction',
};

// ---------------------------------------------------------------- category and type steps

TransactionType _txOf(String? v) =>
    v == 'rent' ? TransactionType.rent : TransactionType.buy;

/// Buy or Rent, step two: the four categories. Choosing one opens its property types directly.
class AQCategoryStepScreen extends StatelessWidget {
  final String? tx;
  const AQCategoryStepScreen({super.key, this.tx});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final t = _txOf(tx);
    return Scaffold(
      backgroundColor: c.background,
      body: aqPage(
        context,
        hero: AQHero(
          image: 'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
          title: f.t('hubcat.${t.name}'),
          sub: f.t('hubcat.sub'),
          onBack: () => aqBack(context, '/properties'),
        ),
        children: [
          LayoutBuilder(
            builder: (context, box) {
              const gap = AQSpacing.x2;
              const cols = 2;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final k in PropCategory.values)
                    _categoryCard(context, f, k, w, t),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    FlowStrings f,
    PropCategory k,
    double w,
    TransactionType t,
  ) {
    final c = AQColors.of(context);
    final large = aqLargeText(context);
    void open() {
      AQHaptics.selection();
      context.push('/properties/types?tx=${t.name}&cat=${k.name}');
    }

    return SizedBox(
      width: w,
      child: Semantics(
        button: true,
        focusable: true,
        onFocus: () {},
        label: '${f.t(k.key)}. ${f.t('pt.c.${k.name}')}',
        excludeSemantics: true,
        onTap: open,
        child: AQPressable(
          onTap: open,
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
                    aspectRatio: 1.45,
                    child: ExcludeSemantics(
                      child: aqImg(k.image, cacheWidth: 380),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AQIcon(_catIcon(k), size: 22, color: c.accent),
                        const SizedBox(height: AQSpacing.x1),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            f.t(k.key),
                            maxLines: 1,
                            style: AQTypography.of(context, AQText.titleSmall),
                          ),
                        ),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: large ? 0 : 54,
                          ),
                          child: Text(
                            f.t('pt.c.${k.name}'),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              soft: true,
                            ),
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
      ),
    );
  }
}

/// Buy or Rent, step three: the property types of the chosen category. For Rent only the types
/// that can be rented are shown. Choosing one opens the results with everything chosen so far.
class AQTypeStepScreen extends StatelessWidget {
  final String? tx, cat;
  const AQTypeStepScreen({super.key, this.tx, this.cat});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final t = _txOf(tx);
    final k = PropCategory.values.firstWhere(
      (e) => e.name == cat,
      orElse: () => PropCategory.residential,
    );
    final types = browseTypesFor(k, t);
    final large = aqLargeText(context);
    return Scaffold(
      backgroundColor: c.background,
      body: aqPage(
        context,
        hero: AQHero(
          image: k.image,
          eyebrow: f.t('hubty.sub.${t.name}'),
          title: f.t(k.key),
          sub: f.t('pt.sec.${k.name}'),
          onBack: () => aqBack(context, '/properties/categories?tx=${t.name}'),
        ),
        children: [
          if (t == TransactionType.rent)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: Text(
                f.t('hubty.rentNote'),
                style: AQTypography.of(context, AQText.bodySmall, soft: true),
              ),
            ),
          LayoutBuilder(
            builder: (context, box) {
              const gap = AQSpacing.x2;
              final cols = large ? 1 : 2;
              final w = (box.maxWidth - gap * (cols - 1)) / cols;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final s in types) _typeCard(context, f, s, w, t, k),
                ],
              );
            },
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AQTextButton(
              label: f.t('hubty.all'),
              color: c.accentDeep,
              trailingIcon: 'chevron-right',
              onPressed: () =>
                  context.push('/properties/all?tx=${t.name}&cat=${k.name}'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeCard(
    BuildContext context,
    FlowStrings f,
    (PropertyType, String) s,
    double w,
    TransactionType t,
    PropCategory k,
  ) {
    final c = AQColors.of(context);
    final label = f.t('bt.${s.$1.name}');
    void open() {
      AQHaptics.selection();
      context.push(
        '/properties/all?tx=${t.name}&cat=${k.name}&types=${s.$1.name}',
      );
    }

    return SizedBox(
      width: w,
      child: Semantics(
        button: true,
        focusable: true,
        onFocus: () {},
        label: label,
        excludeSemantics: true,
        onTap: open,
        child: AQPressable(
          onTap: open,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.surface,
                border: Border.all(color: c.hairline),
                borderRadius: BorderRadius.circular(AQRadius.medium),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AspectRatio(
                    aspectRatio: 1.25,
                    child: ExcludeSemantics(
                      child: aqImg(s.$2, cacheWidth: 380),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AQTypography.of(context, AQText.titleSmall),
                          ),
                        ),
                        AQIcon(
                          'chevron-right',
                          size: 14,
                          color: c.inkSoft,
                          directional: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
