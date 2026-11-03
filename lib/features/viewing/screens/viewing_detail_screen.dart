import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/aq/aq_primitives.dart';
import '../../../core/aq/aq_scene.dart';
import '../../../core/aq/aq_tokens.dart';
import '../../../core/aq/aq_typography.dart';
import '../../../core/localization/viewing_strings.dart';
import '../domain/viewing_models.dart';
import '../domain/viewing_presentation.dart';
import '../widgets/viewing_components.dart';
import '../widgets/viewing_scaffold.dart';
import 'viewing_kit.dart';
import 'viewing_status_screens.dart';

/// Screen 47: the user's definitive appointment record. One architecture for every
/// status; only the sections and actions the state allows are rendered.
class ViewingDetailScreen extends StatelessWidget {
  final String id;
  const ViewingDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final v = ViewingStrings.of(context);
    final c = AQColors.of(context);
    return ViewingLoader(
      id: id,
      title: v.t('vw.detail.title'),
      onBack: () => aqBack(context, '/app/activity'),
      builder: (context, ref, viewing, property) {
        final pres = ViewingPresentation.of(viewing);
        final actions = [for (final a in pres.actions) if (a != ViewingAction.writeReview || viewing.reviewEligible) a];

        final compact = MediaQuery.sizeOf(context).width < 400;
        String full(ViewingAction a) => switch (a) {
              ViewingAction.cancel => v.t('vw.action.cancel'),
              ViewingAction.reschedule => v.t('vw.action.reschedule'),
              ViewingAction.tryAnotherSlot => v.t('vw.tryOther'),
              ViewingAction.scheduleAnother => v.t('vw.scheduleNew'),
              ViewingAction.browseSimilar => v.t('vw.browseSimilar'),
              ViewingAction.writeReview => v.t('vw.rate.write'),
              ViewingAction.backToProperty => v.t('vw.backToProperty'),
              ViewingAction.viewMyViewings => v.t('vw.viewMy'),
            };
        String label(ViewingAction a) => compact ? v.t('vw.short.${a.name}') : full(a);
        void run(ViewingAction a) => switch (a) {
              ViewingAction.cancel => context.push('/viewings/${viewing.id}/cancel'),
              ViewingAction.reschedule => context.push('/viewings/${viewing.id}/reschedule'),
              ViewingAction.tryAnotherSlot || ViewingAction.scheduleAnother => context.push('/property/${viewing.propertyId}/viewing'),
              ViewingAction.browseSimilar => aqBrowseSimilar(context, property.valueOrNull),
              ViewingAction.writeReview => context.push('/viewings/${viewing.id}/review'),
              ViewingAction.backToProperty => context.go('/property/${viewing.propertyId}'),
              ViewingAction.viewMyViewings => context.go('/app/activity'),
            };
        Widget button(ViewingAction a, {required bool primary}) {
          if (primary) {
            final icon = a == ViewingAction.writeReview ? 'star' : (a == ViewingAction.tryAnotherSlot || a == ViewingAction.scheduleAnother || a == ViewingAction.reschedule ? 'calendar' : null);
            return AQPrimaryButton(label: label(a), leadingIcon: icon, trailingChevron: icon == null, onPressed: () => run(a));
          }
          return AQBarSecondaryButton(label: label(a), foreground: a == ViewingAction.cancel ? c.danger : null, onPressed: () => run(a));
        }

        return AQViewingScaffold(
          backLabel: v.t('vw.back'),
          onBack: () => aqBack(context, '/app/activity'),
          bottom: actions.isEmpty
              ? null
              : AQBottomActionBar(
                  primary: actions.first == ViewingAction.cancel ? button(actions.first, primary: false) : button(actions.first, primary: true),
                  secondary: actions.length > 1 ? button(actions[1], primary: false) : null,
                  compact: compact,
                ),
          children: [
            property.when(
              loading: () => const AQViewingSkeleton(height: 280),
              error: (_, _) => const SizedBox.shrink(),
              data: (p) => p == null ? const SizedBox.shrink() : AQViewingPropertySummary(property: p, density: AQViewingDensity.large),
            ),
            const SizedBox(height: AQSpacing.x4),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Flexible(child: AQViewingStatus(presentation: pres)),
            ]),
            const SizedBox(height: AQSpacing.x2),
            Text(v.t(pres.summaryKey), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
            const SizedBox(height: AQSpacing.x4),
            AQViewingDetailCard(slot: viewing.slot, title: v.t('vw.detail.about'), tone: pres.tone == AQTone.success ? AQTone.success : AQTone.neutral),
            if (viewing.rescheduleOffered) ...[
              const SizedBox(height: AQSpacing.x3),
              AQNoticeCard(icon: 'refresh', tone: AQTone.warning, title: v.t('vw.resched.title'), body: v.t('vw.sum.reschedule')),
            ],
            if (viewing.status == ViewingStatus.declined && viewing.declineReason != null) ...[
              const SizedBox(height: AQSpacing.x3),
              AQNoticeCard(icon: 'info', title: v.t('vw.declined.reason'), body: viewing.declineReason!),
            ],
            if (pres.stage != null) ...[
              AQViewingSectionTitle(v.t('vw.timeline')),
              AQSurface(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: AQSpacing.x4), child: AQViewingTimeline(current: pres.stage!, includeCompleted: true)),
            ],
            if (viewing.isActive) ...[
              AQViewingSectionTitle(v.t('vw.meeting'), icon: 'pin'),
              AQViewingLocationCard(
                place: property.valueOrNull?.locationLabel.split(',').take(2).join(',').trim() ?? '',
                note: viewing.status == ViewingStatus.confirmed ? v.t('vw.meeting.confirmed') : v.t('vw.meeting.pending'),
              ),
            ],
            AQViewingSectionTitle(v.t('vw.host'), icon: 'user'),
            AQViewingHostCard(host: viewing.host, showContactNote: viewing.status == ViewingStatus.requested),
            if (viewing.reviewEligible) ...[
              const SizedBox(height: AQSpacing.x4),
              AQReviewEligibilityCard(hostName: viewing.host.name, onRate: (r) => context.push('/viewings/${viewing.id}/review?rating=$r')),
            ],
            AQDemoHostControls(viewing: viewing),
          ],
        );
      },
    );
  }
}
