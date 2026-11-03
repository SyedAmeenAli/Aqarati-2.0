import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider, verificationProvider;
import '../agent/agent_shell.dart' show WorkspaceSideRail, kWorkspaceRailFrom, kWorkspaceRailWidth;
import '../role_home/home_agent.dart' show AgentHome;
import '../role_home/home_construction.dart';
import '../role_home/home_developer.dart';
import '../role_home/home_studio.dart';
import '../role_home/mode_switch.dart';
import '../role_home/role_home_model.dart';
import '../viewing/widgets/viewing_scaffold.dart';

/// One destination of a professional workspace.
class ProTab {
  final String icon, labelKey, route;

  /// Locations that keep this tab selected.
  final List<String> prefixes;
  const ProTab(this.icon, this.labelKey, this.route, this.prefixes);
}

/// The four professional roles each get their own six-destination navigation: different tabs,
/// different words, pointing at the pages that role actually works in. Analytics is always a
/// destination of its own; the last tab is the role's company or profile hub (`/pro/more`), which
/// also holds business settings, reviews and verification status.
const _hubPrefixes = [
  '/pro/more',
  '/pro/settings',
  '/app/account/workspace/profile',
  '/app/account/workspace/reviews',
  '/app/account/workspace',
];
const _projectsPrefixes = ['/app/account/workspace/projects', '/workspace/projects'];
const _leadsPrefixes = ['/app/account/workspace/leads', '/workspace/leads'];
const _engagementsPrefixes = ['/app/account/workspace/engagements', '/workspace/engagements'];
const _portfolioPrefixes = ['/app/account/workspace/portfolio'];
/// Pages that are bar destinations for some roles and live under More for the others.
const _moreSubPages = {'/pro/analytics', '/pro/units', '/pro/projects', '/pro/services'};

/// The full set (tablet and desktop rail). On a phone [compact] gives the four destinations the role
/// works in every day plus More; Analytics and the company or profile hub are reached from More, and
/// the More tab stays selected on them.
List<ProTab> proTabsFor(HomeRole r, {bool compact = false}) {
  final full = _fullProTabs(r);
  if (!compact || full.isEmpty) return full;
  // Day-to-day order per role (indices into the full set).
  final pick = switch (r) {
    HomeRole.developer => const [0, 1, 3, 2],
    _ => const [0, 1, 2, 3],
  };
  final kept = [for (final i in pick) full[i]];
  final dropped = [for (var i = 0; i < full.length; i++) if (!pick.contains(i)) full[i]];
  return [
    ...kept,
    ProTab('more', 'pn.more', '/pro/more', [for (final t in dropped) ...t.prefixes, '/pro/more']),
  ];
}

List<ProTab> _fullProTabs(HomeRole r) => switch (r) {
  HomeRole.developer => const [
    ProTab('home', 'pn.overview', '/pro', ['/pro/home']),
    ProTab('development', 'pn.projects', '/app/account/workspace/projects', _projectsPrefixes),
    ProTab('area', 'pn.units', '/pro/units', ['/pro/units']),
    ProTab('send', 'pn.enquiries', '/app/account/workspace/leads', _leadsPrefixes),
    ProTab('chart', 'an.title', '/pro/analytics', ['/pro/analytics']),
    ProTab('account', 'pn.company', '/pro/more', [..._hubPrefixes, ..._engagementsPrefixes]),
  ],
  HomeRole.construction => const [
    ProTab('home', 'pn.overview', '/pro', ['/pro/home']),
    ProTab('construction', 'pn.projects', '/pro/projects', ['/pro/projects']),
    ProTab('send', 'pn.requests', '/app/account/workspace/leads', _leadsPrefixes),
    ProTab('verified', 'pn.services', '/pro/services', ['/pro/services']),
    ProTab('chart', 'an.title', '/pro/analytics', ['/pro/analytics']),
    ProTab('account', 'pn.company', '/pro/more', [..._hubPrefixes, ..._portfolioPrefixes, ..._engagementsPrefixes]),
  ],
  HomeRole.architecture => const [
    ProTab('home', 'pn.studio', '/pro', ['/pro/home']),
    ProTab('architecture', 'pn.portfolio', '/app/account/workspace/portfolio', _portfolioPrefixes),
    ProTab('development', 'pn.projects', '/pro/projects', ['/pro/projects']),
    ProTab('send', 'pn.enquiries', '/app/account/workspace/leads', _leadsPrefixes),
    ProTab('chart', 'an.title', '/pro/analytics', ['/pro/analytics']),
    ProTab('user', 'pn.profile', '/pro/more', [..._hubPrefixes, ..._engagementsPrefixes]),
  ],
  HomeRole.interiorExterior => const [
    ProTab('home', 'pn.studio', '/pro', ['/pro/home']),
    ProTab('interior', 'pn.portfolio', '/app/account/workspace/portfolio', _portfolioPrefixes),
    ProTab('verified', 'pn.services', '/pro/services', ['/pro/services']),
    ProTab('calendar', 'pn.engagements', '/app/account/workspace/engagements', _engagementsPrefixes),
    ProTab('chart', 'an.title', '/pro/analytics', ['/pro/analytics']),
    ProTab('user', 'pn.profile', '/pro/more', [..._hubPrefixes, ..._projectsPrefixes, ..._leadsPrefixes]),
  ],
  _ => const [],
};

bool isProRole(HomeRole r) =>
    r == HomeRole.developer ||
    r == HomeRole.construction ||
    r == HomeRole.architecture ||
    r == HomeRole.interiorExterior;

int proTabIndex(List<ProTab> tabs, String path) {
  // Longest matching prefix wins, so a project page stays under Projects, not under More.
  var best = -1, bestLen = -1;
  for (var i = 0; i < tabs.length; i++) {
    for (final p in tabs[i].prefixes) {
      if (path == p || path.startsWith('$p/')) {
        if (p.length > bestLen) {
          best = i;
          bestLen = p.length;
        }
      }
    }
  }
  return best < 0 ? 0 : best;
}

/// The business workspace frame for an approved Development, Construction, Architecture or
/// Interior & Exterior account. Not the customer shell, and not the agent's.
class ProShell extends ConsumerStatefulWidget {
  final Widget child;
  const ProShell({super.key, required this.child});
  @override
  ConsumerState<ProShell> createState() => _ProShellState();
}

class _ProShellState extends ConsumerState<ProShell> {
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
    final me = ref.watch(meProvider);
    final res = resolveHome(me.valueOrNull);
    final allowed = me.hasValue && isProRole(res.role);
    if (!allowed) {
      return Scaffold(
        backgroundColor: c.background,
        body: me.isLoading && !me.hasValue
            ? const Center(child: CircularProgressIndicator())
            : WorkspaceAccessNotice(title: f.t('pn.noAccess.t'), next: '/work'),
      );
    }
    final wide = MediaQuery.sizeOf(context).width >= kWorkspaceRailFrom;
    // Phones get four destinations plus More; the rail shows every destination.
    final tabs = proTabsFor(res.role, compact: !wide);
    final path = GoRouterState.of(context).uri.path;
    final index = proTabIndex(tabs, path);
    final items = [for (final t in tabs) AQNavItem(t.icon, f.t(t.labelKey))];
    void go(int i) {
      _nav.setCompact(false);
      if (i != index || path != tabs[i].route) context.go(tabs[i].route);
    }

    // Operational pages sit on a clean warm surface; photography is kept for where it means something.
    final backdrop = ColoredBox(color: c.background);
    // On a phone, Analytics, Units, Projects and Services that sit under More are one level down: they get a
    // visible Back to More. Where the page is a bar destination of this role (or the rail shows it) it stays a root.
    // A page that is not one of this role's own bar destinations (a role opening another role's page by link) is also one level down.
    final underMore = !wide && _moreSubPages.contains(path) && !tabs.any((t) => t.route == path);
    // The bar is painted after the page: the page's own navigator blocks the semantics of anything painted before it.
    final topInset = MediaQuery.paddingOf(context).top;
    final Widget content = underMore
        ? Stack(fit: StackFit.expand, children: [
            Padding(padding: EdgeInsets.only(top: topInset + AQControl.tap), child: widget.child),
            PositionedDirectional(top: topInset, start: 0, end: 0, child: AQTopBar(onBack: () => aqBack(context, index == tabs.length - 1 ? '/pro/more' : '/pro'), backLabel: f.t('common.back'))),
          ])
        : widget.child;
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
                  child: Stack(fit: StackFit.expand, children: [backdrop, AQShellInset(height: 0, child: widget.child)]),
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
                backdrop,
                AQShellInset(
                  height: 84 + MediaQuery.paddingOf(context).bottom,
                  child: NotificationListener<ScrollNotification>(onNotification: _nav.onScroll, child: content),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AQGlassNav(items: items, index: index, controller: _nav, onSelected: go),
                ),
              ],
            ),
    );
  }
}

/// `/pro`: the role's own home (its existing distinct page), inside the business shell.
class ProHomeScreen extends ConsumerWidget {
  const ProHomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(homeResolutionProvider).role;
    return switch (r) {
      HomeRole.developer => const DeveloperHome(),
      HomeRole.construction => const ConstructionHome(),
      HomeRole.architecture => const ArchitectureHome(),
      HomeRole.interiorExterior => const InteriorHome(),
      HomeRole.agent => const AgentHome(),
      HomeRole.buyer => const SizedBox.shrink(),
    };
  }
}

/// `/pro/more`: reviews, status, the way into the shopper app, and sign out.
class ProMoreScreen extends ConsumerWidget {
  const ProMoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final role = ref.watch(homeResolutionProvider).role;
    final phone = MediaQuery.sizeOf(context).width < kWorkspaceRailFrom;
    final hubTitle = f.t(phone ? 'pn.more' : (role == HomeRole.architecture || role == HomeRole.interiorExterior ? 'pn.profile' : 'pn.company'));
    // Destinations this role works in but that are not among its six tabs.
    final tabRoutes = {for (final t in proTabsFor(role, compact: phone)) t.route};
    final extras = <(String, String, String)>[
      if (role == HomeRole.construction) ('architecture', 'pn.portfolio', '/app/account/workspace/portfolio'),
      if (!tabRoutes.contains('/app/account/workspace/engagements')) ('verified', 'pn.engagements', '/app/account/workspace/engagements'),
      if (role == HomeRole.interiorExterior) ('send', 'pn.enquiries', '/app/account/workspace/leads'),
      if (role == HomeRole.interiorExterior) ('development', 'pn.projects', '/app/account/workspace/projects'),
    ];
    Widget row(String icon, String title, VoidCallback onTap, {String? sub, bool danger = false}) => Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: sub == null ? title : '$title. $sub',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x2),
          child: Row(children: [
            AQIcon(icon, size: 20, color: danger ? c.danger : c.accent),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AQTypography.of(context, AQText.bodyMedium, color: danger ? c.danger : c.ink)),
                if (sub != null) Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ]),
            ),
            AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
          ]),
        ),
      ),
    );
    Widget group(String title, List<Widget> rows) => Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.labelMedium, soft: true)))),
        Container(
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline, indent: AQSpacing.x4, endIndent: AQSpacing.x4),
              rows[i],
            ],
          ]),
        ),
      ]),
    );
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x4, AQSpacing.gutter, AQSpacing.x6 + AQShellInset.of(context) + 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Semantics(header: true, child: Text(hubTitle, style: AQTypography.of(context, AQText.headlineLarge))),
              const SizedBox(height: AQSpacing.x4),
              group(f.t('pn.m.business'), [
                row('chart', f.t('an.title'), () => context.push('/pro/analytics')),
                row('account', f.t('pn.m.profile'), () => context.push('/app/account/workspace/profile'), sub: f.t('pn.m.profile.s')),
                row('user', f.t('st.bz.link'), () => context.push('/pro/settings')),
                for (final e in extras) row(e.$1, f.t(e.$2), () => context.push(e.$3)),
                row('star', f.t('pn.m.reviews'), () => context.push('/app/account/workspace/reviews')),
                row('verified', f.t('pn.m.status'), () => context.push('/verification/details')),
                row('info', f.t('pn.m.workspace'), () => context.push('/app/account/workspace')),
              ]),
              group(f.t('pn.m.account'), [
                row('user', f.t('pp.title'), () => context.push('/app/account/photo')),
                row('home', f.t('pn.m.customer'), () => switchToShop(context, ref), sub: f.t('pn.m.customer.s')),
                row('lock', f.t('ag.more.signOut'), () async {
                  await ref.read(authRepositoryProvider).signOut();
                  ref.invalidate(meProvider);
                  ref.invalidate(verificationProvider);
                  if (context.mounted) context.go('/entry');
                }),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
