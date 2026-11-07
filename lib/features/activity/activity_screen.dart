import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_tokens.dart';
import '../../core/localization/flow_strings.dart';
import '../maintenance/maintenance_screens.dart';
import '../viewing/screens/my_viewings_screen.dart';
import '../contact/contact_actions.dart' show ChatsView;
import 'activity_sections.dart';
import '../search/aq_filter_sheet.dart' show AQChoicePill;

/// Which Activity list is open: 0 viewings, 1 maintenance, 2 selling, 3 requests, 4 chats. Kept for the app session.
final activityTabProvider = StateProvider<int>((ref) => 0);

/// The Activity tab: a viewing list and a maintenance-request list behind one switch. Both lists
/// keep their own states (loading, empty, error); nothing here invents entries.
class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final tab = ref.watch(activityTabProvider);
    return Column(children: [
      SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x3, AQSpacing.gutter, 0),
              // Five kinds of record, one at a time. They wrap onto a second line so none is hidden off-screen.
              child: Wrap(
                spacing: AQSpacing.x2,
                runSpacing: AQSpacing.x2,
                children: [
                  for (var i = 0; i < 5; i++)
                    AQChoicePill(
                      label: f.t(['act.viewings', 'act.maintenance', 'act.submissions', 'act.requests', 'act.chats'][i]),
                      selected: tab == i,
                      onTap: () => ref.read(activityTabProvider.notifier).state = i,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      Expanded(
        child: AnimatedSwitcher(
          duration: AQMotion.scaled(context, AQMotion.fast),
          child: KeyedSubtree(key: ValueKey(tab), child: switch (tab) { 0 => const MyViewingsScreen(), 1 => const MaintenanceBookingsView(), 2 => const SubmissionsView(), 3 => const RequestsView(), _ => const ChatsView() }),
        ),
      ),
    ]);
  }
}
