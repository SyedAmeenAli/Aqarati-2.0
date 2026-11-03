import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import 'calculator_models.dart';

String _icon(CalculatorType t) => switch (t) {
      CalculatorType.emi => 'calendar',
      CalculatorType.affordability => 'home',
      CalculatorType.downPayment => 'shield',
      CalculatorType.rentalYield => 'explore',
      CalculatorType.roi => 'star',
      CalculatorType.rentVsBuy => 'refresh',
      CalculatorType.appreciation => 'sunrise',
      CalculatorType.constructionCost => 'construction',
    };

class CalculatorsListScreen extends StatelessWidget {
  const CalculatorsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return AQViewingScaffold(
      title: f.t('calc.title'),
      subtitle: f.t('calc.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/explore'),
      children: [
        for (final t in CalculatorType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Semantics(
              button: true,
              focusable: true,
              onFocus: () {},
              label: '${f.t('calc.t.${t.name}')}. ${f.t('calc.d.${t.name}')}',
              excludeSemantics: true,
      onTap: () {
                  AQHaptics.selection();
                  context.push('/calculators/${t.name}');
                },
              child: AQPressable(
                onTap: () {
                  AQHaptics.selection();
                  context.push('/calculators/${t.name}');
                },
                child: Container(
                  constraints: const BoxConstraints(minHeight: 76),
                  padding: const EdgeInsets.all(AQSpacing.x4),
                  decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
                  child: Row(children: [
                    Container(width: 44, height: 44, decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle), child: Center(child: AQIcon(_icon(t), size: 22, color: c.accent))),
                    const SizedBox(width: AQSpacing.x3),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(f.t('calc.t.${t.name}'), style: AQTypography.of(context, AQText.titleMedium)),
                        Text(f.t('calc.d.${t.name}'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                      ]),
                    ),
                    AQIcon('chevron-right', size: 20, color: c.inkSoft, directional: true),
                  ]),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
