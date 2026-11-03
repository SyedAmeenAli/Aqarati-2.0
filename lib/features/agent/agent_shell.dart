import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../listings/agent_guard.dart';
import '../role_home/role_home_model.dart' show resolveHome;
import '../viewing/widgets/viewing_scaffold.dart' show AQShellInset;

const _agentTabs = [
  '/agent',
  '/agent/listings',
  '/agent/contacts',
  '/agent/calendar',
  '/agent/analytics',
  '/agent/more',
];
const _agentIcons = ['home', 'development', 'account', 'calendar', 'chart', 'more'];
const _agentKeys = [
  'ag.nav.dashboard',
  'ag.nav.listings',
  'ag.nav.contacts',
  'ag.nav.calendar',
  'an.title',
  'ag.nav.more',
];

/// Which agent destination a location belongs to. Leads, enquiries and service requests are
/// reached from More, so they keep More selected.
int agentTabFor(String path) {
  if (path == '/agent') return 0;
  if (path.startsWith('/agent/listings')) return 1;
  if (path.startsWith('/agent/contacts')) return 2;
  if (path.startsWith('/agent/calendar')) return 3;
  if (path.startsWith('/agent/analytics')) return 4;
  return 5;
}

/// The Real Estate Agent workspace frame. It is NOT the customer shell: its own six
/// destinations, a bottom bar on phones and a side rail on wide screens, and only an approved
/// agent gets past the guard.
class AgentShell extends ConsumerStatefulWidget {
  final Widget child;
  const AgentShell({super.key, required this.child});
  @override
  ConsumerState<AgentShell> createState() => _AgentShellState();
}

class _AgentShellState extends ConsumerState<AgentShell> {
  final _nav = AQNavController();
  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final path = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).width >= kWorkspaceRailFrom;
    // Phones: Dashboard, Listings, Contacts, Calendar and More (Analytics lives in More). The rail
    // shows all six. `slots` maps a bar position to the destination it opens.
    final slots = wide ? const [0, 1, 2, 3, 4, 5] : const [0, 1, 2, 3, 5];
    final full = agentTabFor(path);
    final index = wide ? full : (full >= 4 ? 4 : full);
    final items = [
      for (final i in slots) AQNavItem(_agentIcons[i], f.t(i == 5 ? 'ag.nav.more' : _agentKeys[i])),
    ];
    void go(int i) {
      _nav.setCompact(false);
      final route = _agentTabs[slots[i]];
      if (i != index || path != route) context.go(route);
    }

    // Only an approved agent gets the agent navigation; anyone else sees the explanation alone.
    final me = ref.watch(meProvider);
    final allowed = me.hasValue && resolveHome(me.valueOrNull).canSwitch;
    final body = AgentGuard(
      title: f.t('ag.nav.dashboard'),
      backFallback: '/entry',
      builder: (_) => widget.child,
    );
    if (!allowed) return body;
    return Scaffold(
      backgroundColor: c.background,
      // The rail is painted after the content (and placed at the start edge): the page's own
      // navigator blocks the semantics of whatever is painted before it, which would hide the
      // rail from screen readers and the keyboard.
      body: wide
          ? Stack(
              fit: StackFit.expand,
              children: [
                PositionedDirectional(
                  start: kWorkspaceRailWidth,
                  end: 0,
                  top: 0,
                  bottom: 0,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Operational pages sit on a clean warm surface; photography is kept for where it means something.
                      ColoredBox(color: AQColors.of(context).background),
                      AQShellInset(height: 0, child: body),
                    ],
                  ),
                ),
                PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: kWorkspaceRailWidth,
                  child: WorkspaceSideRail(items: items, index: index, onSelected: go),
                ),
              ],
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: AQColors.of(context).background),
                AQShellInset(
                  height: 84 + MediaQuery.paddingOf(context).bottom,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _nav.onScroll,
                    child: body,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AQGlassNav(
                    items: items,
                    index: index,
                    controller: _nav,
                    onSelected: go,
                  ),
                ),
              ],
            ),
    );
  }
}

/// From this width a business workspace shows the full side rail instead of the phone bar.
const double kWorkspaceRailFrom = 700;

/// Width of the side rail the business workspaces show on wide screens.
const double kWorkspaceRailWidth = 232;

class WorkspaceSideRail extends StatelessWidget {
  final List<AQNavItem> items;
  final int index;
  final ValueChanged<int> onSelected;
  const WorkspaceSideRail({
    required this.items,
    required this.index,
    required this.onSelected,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      width: kWorkspaceRailWidth,
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        border: BorderDirectional(end: BorderSide(color: c.hairline)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x5),
                child: Text(
                  'AQARATI',
                  style: AQTypography.of(context, AQText.titleLarge),
                ),
              ),
              for (var i = 0; i < items.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x1),
                  child: _RailItem(
                    item: items[i],
                    selected: i == index,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final AQNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(
            color: selected ? c.surfaceSelected : Colors.transparent,
            borderRadius: BorderRadius.circular(AQRadius.medium),
          ),
          child: Row(
            children: [
              AQIcon(item.icon, size: 20, color: selected ? c.accent : c.inkSoft),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    color: selected ? c.ink : c.inkSoft,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
