import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_scene.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../role_home/mode_switch.dart' show WorkspaceAccessNotice;
import '../role_home/role_home_model.dart';
import '../viewing/screens/viewing_kit.dart' show AQViewingSkeleton;
import '../viewing/widgets/viewing_scaffold.dart';

/// Only an approved real estate agent reaches the agent workspace. A shopper, a guest and an agent
/// whose application is not approved all see the same calm explanation instead of the screen. The
/// service enforces this too; hiding the screen is usability, not security.
class AgentGuard extends ConsumerWidget {
  final String title;
  final String backFallback;
  final Widget Function(BuildContext context) builder;
  const AgentGuard({
    super.key,
    required this.title,
    this.backFallback = '/app/home',
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final me = ref.watch(meProvider);
    void back() => aqBack(context, backFallback);
    if (me.isLoading && !me.hasValue) {
      return AQViewingScaffold(
        title: title,
        backLabel: f.t('common.back'),
        onBack: back,
        children: const [
          AQViewingSkeleton(height: 96),
          AQViewingSkeleton(height: 96),
        ],
      );
    }
    final resolution = resolveHome(me.valueOrNull);
    if (!resolution.canSwitch) {
      return WorkspaceAccessNotice(title: title, next: '/work', agent: true);
    }
    return builder(context);
  }
}
