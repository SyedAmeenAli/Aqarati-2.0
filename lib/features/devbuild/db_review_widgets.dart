import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../viewing/widgets/viewing_format.dart';
import 'db_models.dart';
import 'db_service_toggles.dart' show DbSwitch;
import 'db_profile.dart' show DbStars;

/// Whether the business's published reviews are shown on its public profile, and whether it wants to be told
/// of a new one. They change the profile preview and this screen at once and are kept on this device in the preview.
final reviewsPublicProvider = StateProvider<bool>((ref) => true);
final reviewsNotifyProvider = StateProvider<bool>((ref) => true);

/// The average, the count and how the ratings split, all computed from the reviews actually listed, so the
/// number, the bars and the cards below can never disagree.
class DbRatingSummary extends StatelessWidget {
  final List<DbReview> reviews;
  const DbRatingSummary({super.key, required this.reviews});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final n = reviews.length;
    final avg = n == 0 ? 0.0 : reviews.fold<int>(0, (a, r) => a + r.rating) / n;
    int count(int s) => reviews.where((r) => r.rating == s).length;
    return Container(
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(VFmt.dec(context, avg, digits: 1), style: AQTypography.of(context, AQText.displaySmall)),
          DbStars(avg.round(), size: 16),
          const SizedBox(height: 2),
          Text(f.t('pro.reviews', {'n': VFmt.n(context, n)}), style: AQTypography.of(context, AQText.labelSmall, soft: true)),
        ]),
        const SizedBox(width: AQSpacing.x4),
        Expanded(
          child: Column(children: [
            for (final s in [5, 4, 3, 2, 1])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  SizedBox(width: 14, child: Text(VFmt.n(context, s), style: AQTypography.of(context, AQText.labelSmall, soft: true))),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: n == 0 ? 0 : count(s) / n, minHeight: 6, color: c.accent, backgroundColor: c.hairline),
                    ),
                  ),
                  SizedBox(width: 24, child: Text(VFmt.n(context, count(s)), textAlign: TextAlign.end, style: AQTypography.of(context, AQText.labelSmall, soft: true))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

/// A labelled switch row that really changes the value it shows.
class DbSettingToggle extends StatelessWidget {
  final String title, sub;
  final bool value;
  final ValueChanged<bool> onChanged;
  const DbSettingToggle({super.key, required this.title, required this.sub, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      toggled: value,
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $sub',
      excludeSemantics: true,
      onTap: () => onChanged(!value),
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onChanged(!value);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x3),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, AQText.titleSmall)),
                Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ]),
            ),
            const SizedBox(width: AQSpacing.x3),
            DbSwitch(on: value),
          ]),
        ),
      ),
    );
  }
}
