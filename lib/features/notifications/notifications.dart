import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_demo.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart';
import '../maintenance/maintenance_repository.dart';
import '../viewing/data/viewing_repository.dart';
import '../viewing/domain/viewing_presentation.dart';
import '../viewing/screens/viewing_kit.dart' show AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';

enum NotificationKind { viewing, maintenance, verification }

/// One update. Built from what the app already holds (viewings, maintenance requests, the
/// application status), never invented. Push delivery is not connected, so this is an in-app
/// inbox of real state changes, not a server feed.
class AppNotification {
  /// Includes the status, so a change creates a new (unread) item.
  final String id;
  final NotificationKind kind;
  final String titleKey;
  final String? subject;
  final DateTime? when;
  final DateTime at;
  final String route;
  const AppNotification({required this.id, required this.kind, required this.titleKey, this.subject, this.when, required this.at, required this.route});
}

/// Deep-link target for a verification notification: always the real status screen.
const kVerificationRoute = '/verification';

String verificationTitleKey(GrantState g, ReviewStage? stage) => switch (g) {
      GrantState.pendingVerification => stage == ReviewStage.awaitingSecondApproval ? 'ntf.ver.second' : 'ntf.ver.pending',
      GrantState.approved => 'ntf.ver.approved',
      GrantState.resubmissionRequired => 'ntf.ver.resub',
      GrantState.rejected => 'ntf.ver.rejected',
      GrantState.suspended => 'ntf.ver.suspended',
      GrantState.draft => '',
    };

/// Which notifications the signed-in person has read (kept on this device).
final readNotificationsProvider = StateProvider<Set<String>>((ref) => {});

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final out = <AppNotification>[];
  var failed = 0;

  try {
    for (final v in await ref.watch(viewingsProvider.future)) {
      final key = v.rescheduleOffered ? 'ntf.vw.reschedule' : 'ntf.vw.${v.status.name}';
      out.add(AppNotification(id: 'vw-${v.id}-${v.status.name}-${v.rescheduleOffered}', kind: NotificationKind.viewing, titleKey: key, when: v.slot.start, at: v.createdAt, route: ViewingPresentation.momentPath(v)));
    }
  } catch (_) {
    failed++;
  }

  try {
    for (final b in await ref.watch(maintenanceBookingsProvider.future)) {
      out.add(AppNotification(id: 'mnt-${b.id}-${b.status.name}', kind: NotificationKind.maintenance, titleKey: 'ntf.mnt.${b.status.name}', subject: b.providerName, when: b.date, at: b.createdAt, route: '/bookings/${b.id}'));
    }
  } catch (_) {
    failed++;
  }

  try {
    final me = await ref.watch(meProvider.future);
    final g = me.grant;
    if (g != null && g != GrantState.draft && me.purpose != null) {
      out.add(AppNotification(id: 'ver-${g.name}-${me.stage?.name}', kind: NotificationKind.verification, titleKey: verificationTitleKey(g, me.stage), at: DateTime.now(), route: kVerificationRoute));
    }
  } catch (_) {
    // A guest has no application: not a failure of the inbox.
  }

  if (failed == 2 && out.isEmpty) {
    // Both list sources failed and there is nothing else to show: say so instead of "nothing new".
    throw StateError('notifications unavailable');
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
});

/// Real unread count. Zero when there is nothing unread, so no badge is ever shown for nothing.
final unreadNotificationsProvider = Provider.autoDispose<int>((ref) {
  final list = ref.watch(notificationsProvider).valueOrNull ?? const <AppNotification>[];
  final read = ref.watch(readNotificationsProvider);
  return list.where((n) => !read.contains(n.id)).length;
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(notificationsProvider);
    final read = ref.watch(readNotificationsProvider);
    final list = async.valueOrNull ?? const <AppNotification>[];
    final unread = list.where((n) => !read.contains(n.id)).length;

    Widget body = async.when(
      loading: () => const Column(children: [AQViewingSkeleton(height: 84), AQViewingSkeleton(height: 84), AQViewingSkeleton(height: 84)]),
      error: (_, _) => AQErrorBanner(text: f.t('ntf.error'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(notificationsProvider))),
      data: (items) {
        if (items.isEmpty) return AQEmptyViewingState(title: f.t('ntf.empty.t'), body: f.t('ntf.empty.b'));
        return Column(children: [
          for (final n in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: _Row(
                n: n,
                unread: !read.contains(n.id),
                onTap: () {
                  ref.read(readNotificationsProvider.notifier).update((s) => {...s, n.id});
                  context.push(n.route);
                },
              ),
            ),
        ]);
      },
    );

    return AQViewingScaffold(
      title: f.t('ntf.title'),
      subtitle: f.t('ntf.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/account'),
      children: [
        AQAnimatedSize(
          duration: AQMotion.fast,
          child: unread > 0
              ? Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: Row(children: [
                    Expanded(child: Semantics(liveRegion: true, child: Text(f.t('ntf.unread', {'n': VFmt.n(context, unread)}), style: AQTypography.of(context, AQText.labelLarge, color: c.accentDeep)))),
                    AQTextButton(label: f.t('ntf.markAll'), color: c.accent, onPressed: () => ref.read(readNotificationsProvider.notifier).update((s) => {...s, ...list.map((n) => n.id)})),
                  ]),
                )
              : const SizedBox(width: double.infinity),
        ),
        AnimatedSwitcher(duration: AQMotion.scaled(context, AQMotion.standard), child: KeyedSubtree(key: ValueKey('${async.isLoading}-${async.hasError}-${list.length}'), child: body)),
        const SizedBox(height: AQSpacing.x3),
        Text(f.t('ntf.note'), style: AQTypography.of(context, AQText.bodySmall, color: c.inkFaint)),
        const SizedBox(height: AQSpacing.x3),
        const AQDemoNotice(),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  final AppNotification n;
  final bool unread;
  final VoidCallback onTap;
  const _Row({required this.n, required this.unread, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final sub = [if (n.subject != null) VFmt.iso(n.subject!), if (n.when != null) VFmt.shortDate(context, n.when!)].join(' · ');
    final title = f.t(n.titleKey);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${unread ? '${f.t('ntf.unread', {'n': '1'})}. ' : ''}$title${sub.isEmpty ? '' : '. $sub'}',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          padding: const EdgeInsets.all(AQSpacing.x4),
          decoration: BoxDecoration(
            color: unread ? c.surfaceSelected : c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: unread ? c.accent.withValues(alpha: 0.5) : c.hairline),
          ),
          child: Row(children: [
            // The kind of update as an icon; unread carries a small accent dot on it, read is quieter.
            Stack(clipBehavior: Clip.none, children: [
              AnimatedContainer(
                duration: AQMotion.scaled(context, AQMotion.fast),
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: unread ? c.surfaceRaised : c.surfaceSelected, border: Border.all(color: unread ? c.accent.withValues(alpha: 0.5) : c.hairline)),
                child: Center(child: AQIcon(switch (n.kind) { NotificationKind.viewing => 'calendar-check', NotificationKind.maintenance => 'wrench', NotificationKind.verification => 'verified' }, size: 20, color: unread ? c.accentDeep : c.inkSoft)),
              ),
              if (unread) PositionedDirectional(end: -1, top: -1, child: Container(width: 12, height: 12, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle, border: Border.all(color: c.surfaceSelected, width: 2)))),
            ]),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, AQText.titleMedium).copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500)),
                if (sub.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              ]),
            ),
            AQIcon('chevron-right', size: 18, color: c.inkSoft, directional: true),
          ]),
        ),
      ),
    );
  }
}
