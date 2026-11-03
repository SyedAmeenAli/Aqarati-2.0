import 'package:flutter/material.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/domain/account_models.dart' show InteriorExteriorServiceType;
import '../../core/localization/flow_strings.dart';

/// Which of the two design services a studio offers, as two independent switches. The contract keeps one
/// value (interior, exterior or both); "both" is only what you get when both switches are on, never a
/// third choice, and none on means no service selected.
({bool interior, bool exterior}) serviceFlags(InteriorExteriorServiceType? v) => (
  interior: v == InteriorExteriorServiceType.interior || v == InteriorExteriorServiceType.both,
  exterior: v == InteriorExteriorServiceType.exterior || v == InteriorExteriorServiceType.both,
);

InteriorExteriorServiceType? serviceFromFlags(bool interior, bool exterior) => interior && exterior
    ? InteriorExteriorServiceType.both
    : (interior ? InteriorExteriorServiceType.interior : (exterior ? InteriorExteriorServiceType.exterior : null));

/// Plain description of what is offered: "Interior", "Exterior", "Interior + Exterior" or "None selected".
String serviceSummary(FlowStrings f, InteriorExteriorServiceType? v) => switch (v) {
  InteriorExteriorServiceType.interior => f.t('svc.interior.t'),
  InteriorExteriorServiceType.exterior => f.t('svc.exterior.t'),
  InteriorExteriorServiceType.both => f.t('svc.both'),
  null => f.t('svc.noneSelected'),
};

class DbServiceToggles extends StatelessWidget {
  final InteriorExteriorServiceType? value;
  final ValueChanged<InteriorExteriorServiceType?> onChanged;

  /// When false, turning off the last service is ignored (a sign-up needs one).
  final bool allowNone;
  const DbServiceToggles({super.key, required this.value, required this.onChanged, this.allowNone = true});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final fl = serviceFlags(value);
    void set(bool interior, bool exterior) {
      if (!allowNone && !interior && !exterior) return;
      AQHaptics.selection();
      onChanged(serviceFromFlags(interior, exterior));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(f.t('svc.hint'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      const SizedBox(height: AQSpacing.x3),
      _ServiceRow(icon: 'interior', title: f.t('svc.interior.t'), sub: f.t('svc.interior.s'), on: fl.interior, onChanged: (v) => set(v, fl.exterior)),
      const SizedBox(height: AQSpacing.x2),
      _ServiceRow(icon: 'architecture', title: f.t('svc.exterior.t'), sub: f.t('svc.exterior.s'), on: fl.exterior, onChanged: (v) => set(fl.interior, v)),
      const SizedBox(height: AQSpacing.x2),
      Semantics(
        liveRegion: true,
        child: Text(
          value == null ? f.t('svc.none') : f.t('svc.offered', {'v': serviceSummary(f, value)}),
          style: AQTypography.of(context, AQText.labelMedium, color: value == null ? c.danger : c.accentDeep),
        ),
      ),
    ]);
  }
}

class _ServiceRow extends StatelessWidget {
  final String icon, title, sub;
  final bool on;
  final ValueChanged<bool> onChanged;
  const _ServiceRow({required this.icon, required this.title, required this.sub, required this.on, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      toggled: on,
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: () => onChanged(!on),
      child: AQPressable(
        onTap: () => onChanged(!on),
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x3),
          decoration: BoxDecoration(
            color: on ? c.surfaceSelected : c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: on ? c.accent : c.hairline, width: on ? 1.5 : 1),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.accent.withValues(alpha: on ? 0.18 : 0.08), shape: BoxShape.circle),
              child: Center(child: AQIcon(icon, size: 20, color: on ? c.accent : c.inkSoft)),
            ),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, AQText.titleSmall)),
                Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ]),
            ),
            const SizedBox(width: AQSpacing.x3),
            DbSwitch(on: on),
          ]),
        ),
      ),
    );
  }
}

class DbSwitch extends StatelessWidget {
  final bool on;
  const DbSwitch({super.key, required this.on});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final d = AQMotion.scaled(context, const Duration(milliseconds: 180));
    return AnimatedContainer(
      duration: d,
      width: 52,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: on ? c.accent : c.hairline, borderRadius: BorderRadius.circular(15)),
      child: AnimatedAlign(
        duration: d,
        curve: Curves.easeInOutCubic,
        alignment: on ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
        child: Container(width: 24, height: 24, decoration: BoxDecoration(color: on ? c.onAccent : c.surfaceRaised, shape: BoxShape.circle, boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))])),
      ),
    );
  }
}
