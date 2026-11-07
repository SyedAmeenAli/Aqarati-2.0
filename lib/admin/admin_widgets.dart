import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_demo.dart';
import '../core/aq/aq_forms.dart';
import '../core/aq/aq_glass.dart';
import '../core/aq/aq_primitives.dart';
import '../core/aq/aq_status.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../core/config/backend_mode.dart';
import '../data/api/account_api.dart' show ApiException;
import '../features/devbuild/db_widgets.dart'
    show DbSelectField, showDbChoiceSheet;
import '../features/entry/widgets/entry_common.dart' show MasterLogo;
import '../features/viewing/domain/viewing_presentation.dart' show AQTone;
import '../features/viewing/widgets/viewing_format.dart';
import 'admin_auth.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_ui.dart';
import '../core/localization/entry_strings.dart' show localeProvider;
import 'admin_l10n.dart';

// ------------------------------------------------------------------ copy for error and reason keys

String adminMsg(String key) => tr(switch (key) {
  'adm.err.sponsor' => 'Enter the sponsor name.',
  'adm.err.headline' => 'Enter a headline.',
  'adm.err.cta' => 'Enter the button label.',
  'adm.err.destination' =>
    'Use a secure https address, or an app path that starts with /.',
  'adm.err.image' => 'Choose a banner image.',
  'adm.err.imageType' => 'The banner image must be a JPG or PNG file.',
  'adm.err.imageSize' => 'The banner image must be 5 MB or smaller.',
  'adm.err.schedule' => 'The start date must be before the end date.',
  'adm.err.audience' => 'Choose at least one Home screen for this banner.',
  _ => key,
});

String reasonLabel(ReasonCode c) => tr(switch (c) {
  ReasonCode.docUnreadable => 'Document unreadable',
  ReasonCode.docWrongType => 'Wrong document type',
  ReasonCode.nameMismatch => 'Name does not match',
  ReasonCode.expired => 'Document expired',
  ReasonCode.notOnRegistry => 'Not found on the registry',
  ReasonCode.licenceCategoryMismatch => 'Licence category does not match',
  ReasonCode.ownerMismatch => 'Owner does not match',
  ReasonCode.duplicateListing => 'Duplicate listing',
  ReasonCode.photosMismatch => 'Photos do not match the property',
  ReasonCode.callFailed => 'Call-back failed',
  ReasonCode.incompleteSubmission => 'Incomplete submission',
  ReasonCode.other => 'Other (note required)',
});

String kindLabel(ApplicantKind k) => tr(switch (k) {
  ApplicantKind.agent => 'Real estate agent',
  ApplicantKind.developer => 'Development company',
  ApplicantKind.construction => 'Construction company',
  ApplicantKind.architecture => 'Building architecture',
  ApplicantKind.interiorExterior => 'Interior & exterior design',
});

String roleLabel(AdminRole r) => tr(switch (r) {
  AdminRole.reviewer => 'Reviewer',
  AdminRole.seniorReviewer => 'Senior reviewer',
  AdminRole.superAdmin => 'Super admin',
  AdminRole.auditor => 'Auditor',
});

String queueStatusLabel(QueueStatus s) => tr(switch (s) {
  QueueStatus.pending => 'Waiting for review',
  QueueStatus.awaitingSecondApproval => 'Awaiting second approval',
  QueueStatus.resubmissionRequired => 'Resubmission requested',
  QueueStatus.approved => 'Approved',
  QueueStatus.rejected => 'Rejected',
});

(AQTone, String) queueStatusLook(QueueStatus s) => switch (s) {
  QueueStatus.pending => (AQTone.pending, 'clock'),
  QueueStatus.awaitingSecondApproval => (AQTone.warning, 'user'),
  QueueStatus.resubmissionRequired => (AQTone.warning, 'refresh'),
  QueueStatus.approved => (AQTone.success, 'check'),
  QueueStatus.rejected => (AQTone.danger, 'close'),
};

String moderationStatusLabel(ModerationStatus s) => tr(switch (s) {
  ModerationStatus.pending => 'Waiting for review',
  ModerationStatus.resubmissionRequired => 'Corrections requested',
  ModerationStatus.approved => 'Approved',
  ModerationStatus.rejected => 'Rejected',
});

(AQTone, String) moderationStatusLook(ModerationStatus s) => switch (s) {
  ModerationStatus.pending => (AQTone.pending, 'clock'),
  ModerationStatus.resubmissionRequired => (AQTone.warning, 'refresh'),
  ModerationStatus.approved => (AQTone.success, 'check'),
  ModerationStatus.rejected => (AQTone.danger, 'close'),
};

String decisionLabel(Decision d) => tr(switch (d) {
  Decision.approve => 'Approve',
  Decision.requestResubmission => 'Request resubmission',
  Decision.reject => 'Reject',
});

String sourceLabel(ListingSource s) =>
    tr(s == ListingSource.eBroker ? 'Aqary e-Broker' : 'Agent submission');

/// The message for something that went wrong, in the console's own words. Session expiry is
/// handled by the caller (it ends the session); everything else becomes plain text.
String adminErrorText(Object e) {
  if (e is AdminForbiddenException) {
    return 'Your role cannot do this. Nothing was changed.';
  }
  if (e is AdminLockedException) {
    return '${e.by.isEmpty ? 'Another reviewer' : e.by} is reviewing this item. Nothing was changed.';
  }
  if (e is AdminSameApproverException) {
    return 'A developer application needs two different approvers. A different senior reviewer must give the second approval.';
  }
  if (e is AdminConflictException) {
    return 'This item was already decided. Refresh to see its current status.';
  }
  if (e is ApiException) {
    return 'We could not complete this. Nothing was changed.';
  }
  return 'We could not complete this. Nothing was changed.';
}

/// Ends the session when the service says it ended. Returns true when it did.
bool endSessionIfExpired(WidgetRef ref, Object e) {
  if (e is AdminSessionExpiredException) {
    ref.read(adminAuthProvider.notifier).expire();
    return true;
  }
  return false;
}

// ------------------------------------------------------------------ frame

/// Content rises and fades in, each block a beat after the one above. Off when motion is reduced.
class _Rise extends StatelessWidget {
  final int index;
  final Widget child;
  const _Rise({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final delay = (index.clamp(0, 8)) * 60;
    final total = 420 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      child: child,
      builder: (context, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: child)),
    );
  }
}

String _sectionIcon(String section) => switch (section) {
  '/ads' => 'megaphone',
  '/verification' => 'verified',
  '/moderation' => 'shield',
  '/reports' => 'flag',
  '/accounts' => 'account',
  '/analytics' => 'chart',
  '/audit' => 'clock',
  _ => 'listings',
};

/// Header of a detail page: a back pill, a monogram, the name and its status, on one glass card.
class _DetailHeader extends StatelessWidget {
  final String title, backLabel;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback onBack;
  final String icon;
  const _DetailHeader({required this.title, required this.subtitle, required this.actions, required this.onBack, required this.backLabel, required this.icon});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: Semantics(
          button: true,
          label: backLabel,
          excludeSemantics: true,
          onTap: onBack,
          child: AQPressable(
            onTap: onBack,
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              padding: const EdgeInsetsDirectional.fromSTEB(10, 0, 16, 0),
              decoration: BoxDecoration(color: c.surfaceRaised.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.hairline)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                AQIcon('chevron-left', size: 16, color: c.accentDeep, directional: true),
                const SizedBox(width: 4),
                Flexible(child: Text(backLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep))),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      AQGlass(
        radius: 28,
        blur: 14,
        fill: 0.68,
        padding: const EdgeInsets.all(18),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]),
              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
            ),
            alignment: Alignment.center,
            child: AQIcon(icon, size: 28, color: c.onAccent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.headlineSmall))),
              if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
              if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 10), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
            ]),
          ),
        ]),
      ),
    ]);
  }
}

class _NavItem {
  final String label, icon, route;
  const _NavItem(this.label, this.icon, this.route);
}

class _NavGroup {
  final String? title;
  final List<_NavItem> items;
  const _NavGroup(this.title, this.items);
}

/// Every existing route, grouped by what the person is doing. Nothing here is a placeholder.
const _groups = [
  _NavGroup(null, [_NavItem('Overview', 'home', '/overview')]),
  _NavGroup('People', [
    _NavItem('Accounts', 'account', '/accounts'),
    _NavItem('Verification', 'verified', '/verification'),
    _NavItem('Agents and brokers', 'agent', '/m/brokers'),
  ]),
  _NavGroup('Listings', [
    _NavItem('Listing moderation', 'shield', '/moderation'),
    _NavItem('Property listings', 'listings', '/m/listings'),
    _NavItem('Development projects', 'development', '/m/projects'),
    _NavItem('Construction', 'construction', '/m/construction'),
    _NavItem('Architecture and design', 'architecture', '/m/design'),
  ]),
  _NavGroup('Services', [
    _NavItem('Maintenance', 'wrench', '/m/maintenance'),
    _NavItem('Viewings and requests', 'calendar', '/m/viewings'),
  ]),
  _NavGroup('Marketing', [
    _NavItem('Ads & Sponsors', 'megaphone', '/ads'),
    _NavItem('Announcements', 'send', '/m/announcements'),
    _NavItem('Categories and content', 'grid', '/m/content'),
  ]),
  _NavGroup('Insight', [
    _NavItem('Reports', 'flag', '/reports'),
    _NavItem('Analytics', 'chart', '/analytics'),
    _NavItem('Activity log', 'clock', '/audit'),
  ]),
];

const _settingsItem = _NavItem('Profile and settings', 'user', '/settings');

/// The navigation, used as the fixed sidebar on wide screens and inside the drawer on narrow ones.
class _Sidebar extends ConsumerWidget {
  final String section;
  final bool inDrawer;
  const _Sidebar({required this.section, this.inDrawer = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final s = ref.watch(adminAuthProvider).session;
    return Container(
      width: inDrawer ? null : AdminSize.sidebar,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.surfaceRaised, Color.alphaBlend(c.accent.withValues(alpha: 0.10), c.surfaceRaised)]),
        border: inDrawer ? null : BorderDirectional(end: BorderSide(color: c.hairline)),
        boxShadow: inDrawer ? null : [BoxShadow(color: c.accentDeep.withValues(alpha: 0.08), blurRadius: 24)],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 20, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MasterLogo(width: 76),
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(tr('Admin'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)),
                  ),
                  if (inDrawer) ...[
                    const Spacer(),
                    AdminIconButton(icon: 'close', semanticsLabel: tr('Close navigation'), onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ],
              ),
            ),
            if (true)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
                child: _ProfileCard(name: s?.name ?? '', role: s == null ? '' : roleLabel(s.role)),
              ),
            Divider(height: 1, thickness: 1, color: c.hairline),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (inDrawer)
                      _DrawerGroups(section: section)
                    else
                      for (final g in _groups) ...[
                        if (g.title != null)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(10, 12, 10, 4),
                            child: Text(
                              // Letter-case and tracking are Latin conventions; Arabic keeps its own forms.
                              AdminLang.ar ? AdminLang.t(g.title!) : g.title!.toUpperCase(),
                              style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint).copyWith(letterSpacing: AdminLang.ar ? 0 : 1.1),
                            ),
                          ),
                        for (final n in g.items) _SideItem(item: n, selected: section == n.route, closeDrawer: inDrawer),
                      ],
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: c.hairline),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 0),
              child: _SideItem(item: _settingsItem, selected: section == _settingsItem.route, closeDrawer: inDrawer),
            ),
            const Padding(
              padding: EdgeInsetsDirectional.fromSTEB(12, 4, 12, 0),
              child: Align(alignment: AlignmentDirectional.centerStart, child: AdminLangButton()),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 12, 14),
              child: Row(
                children: [
                  const Spacer(),
                  AdminTextButton(
                    label: tr('Sign out'),
                    color: c.accentDeep,
                    onPressed: () => ref.read(adminAuthProvider.notifier).signOut(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone drawer: the same destinations, folded into sections that open one at a time. The section that
/// holds the current page starts open; the rest are one line each, so the menu reads as a short list.
class _DrawerGroups extends StatefulWidget {
  final String section;
  const _DrawerGroups({required this.section});
  @override
  State<_DrawerGroups> createState() => _DrawerGroupsState();
}

class _DrawerGroupsState extends State<_DrawerGroups> {
  late String? _open = _groupOf(widget.section);

  static String? _groupOf(String route) {
    for (final g in _groups) {
      if (g.title != null && g.items.any((i) => i.route == route)) return g.title;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final g in _groups)
          if (g.title == null)
            for (final n in g.items) _SideItem(item: n, selected: widget.section == n.route, closeDrawer: true)
          else ...[
            Semantics(
              button: true,
              expanded: _open == g.title,
              label: tr(g.title!),
              excludeSemantics: true,
              onTap: () => setState(() => _open = _open == g.title ? null : g.title),
              child: AQPressable(
                onTap: () => setState(() => _open = _open == g.title ? null : g.title),
                pressedScale: 0.99,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 8, 0),
                  child: Row(
                    children: [
                      Expanded(child: Text(tr(g.title!), style: AQTypography.of(context, AQText.titleSmall, color: _open == g.title ? c.accentDeep : c.ink))),
                      AnimatedRotation(
                        turns: _open == g.title ? 0.5 : 0,
                        duration: AQMotion.scaled(context, AQMotion.fast),
                        child: AQIcon('chevron-down', size: 18, color: c.inkSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: AQMotion.scaled(context, AQMotion.fast),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _open == g.title
                  ? Padding(
                      padding: const EdgeInsetsDirectional.only(start: 8, bottom: 4),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final n in g.items) _SideItem(item: n, selected: widget.section == n.route, closeDrawer: true)]),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            Divider(height: 1, thickness: 1, color: c.hairline),
          ],
      ],
    );
  }
}

/// One console page: a sidebar on wide screens, a menu button and drawer on narrow ones, then a
/// compact header (back link, title, one line of context, the page's actions) and the content.
class AdminFrame extends ConsumerWidget {
  final String section;
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final VoidCallback? onBack;
  final String? backLabel;
  final List<Widget> children;
  final List<(String, int)> stats;
  const AdminFrame({
    super.key,
    required this.section,
    required this.title,
    this.subtitle,
    this.actions = const [],
    this.onBack,
    this.backLabel,
    required this.children,
    this.stats = const [],
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final side = wide ? 32.0 : AQSpacing.gutter;

    final detail = onBack != null
        ? _DetailHeader(title: title, subtitle: subtitle, actions: actions, onBack: onBack!, backLabel: backLabel ?? 'Back', icon: _sectionIcon(section))
        : null;
    final header = detail != null
        ? Padding(padding: const EdgeInsets.only(bottom: 20), child: detail)
        : Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onBack != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              // A 44 px tall target, whatever the pointer.
              child: AdminTextButton(
                label: backLabel ?? 'Back',
                leadingIcon: 'chevron-left',
                color: c.accentDeep,
                compact: false,
                onPressed: onBack,
              ),
            ),
          ),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          spacing: 16,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (r) => LinearGradient(colors: [c.ink, c.accentDeep]).createShader(r),
                      child: Text(title, style: AQTypography.of(context, AQText.headlineMedium, color: Colors.white)),
                    ),
                  ),
                  // A short accent line that draws itself in.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => Container(
                      margin: const EdgeInsets.only(top: 8),
                      width: 56 * v,
                      height: 3,
                      decoration: BoxDecoration(gradient: LinearGradient(colors: [c.accent, const Color(0xFFE9C9A0)]), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(subtitle!, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
                    ),
                ],
              ),
            ),
            if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
          ],
        ),
        const SizedBox(height: 20),
      ],
    );

    final body = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AdminSize.content),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(side, wide ? 28 : 12, side, wide ? 56 : 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Rise(index: 0, child: header),
              if (stats.isNotEmpty) _Rise(index: 1, child: AdminStatStrip(stats)),
              for (var i = 0; i < children.length; i++) _Rise(index: i + 1, child: children[i]),
            ],
          ),
        ),
      ),
    );

    if (wide) {
      return Scaffold(
        backgroundColor: c.background,
        body: Row(
          children: [
            _Sidebar(section: section),
            Expanded(child: body),
          ],
        ),
      );
    }
    final screenW = MediaQuery.sizeOf(context).width;
    final rail = screenW >= 600;
    return Scaffold(
      backgroundColor: c.background,
      // A sensible width on any phone (never wider than 86% of it), with its own scrolling list.
      drawer: Drawer(
        width: screenW * 0.86 > 320 ? 320 : screenW * 0.86,
        backgroundColor: c.surfaceRaised,
        child: _Sidebar(section: section, inDrawer: true),
      ),
      extendBody: !rail,
      bottomNavigationBar: rail ? null : _BottomNav(section: section),
      body: AdminAmbient(child: SafeArea(
        bottom: false,
        child: Builder(
          builder: (context) => Column(
            children: [
              Container(
                constraints: const BoxConstraints(minHeight: 52),
                padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 8, 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.surfaceRaised, c.background]),
                  border: Border(bottom: BorderSide(color: c.hairline)),
                  boxShadow: [BoxShadow(color: c.accentDeep.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    if (!rail)
                      AdminIconButton(icon: 'menu', semanticsLabel: tr('Open navigation'), onPressed: () => Scaffold.of(context).openDrawer())
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 2),
                    MasterLogo(width: 52),
                    const SizedBox(width: 8),
                    Expanded(child: Text(tr('Admin'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelLarge, color: c.accentDeep))),
                    const AdminLangButton(),
                  ],
                ),
              ),
              Expanded(
                child: rail
                    ? Row(children: [_Rail(section: section, onMore: () => Scaffold.of(context).openDrawer()), Expanded(child: body)])
                    : body,
              ),
            ],
          ),
        ),
      )),
    );
  }
}

/// Soft warm light behind the content, so frosted surfaces have something to blur.
class AdminAmbient extends StatelessWidget {
  final Widget child;
  const AdminAmbient({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Stack(children: [
      Positioned(top: -120, right: -100, child: _glow(c.accent.withValues(alpha: 0.22), 340)),
      Positioned(top: 380, left: -140, child: _glow(const Color(0xFFD9A877).withValues(alpha: 0.22), 360)),
      Positioned(bottom: -140, right: -80, child: _glow(c.accentDeep.withValues(alpha: 0.16), 320)),
      Positioned.fill(child: child),
    ]);
  }

  Widget _glow(Color color, double size) => IgnorePointer(
    child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]))),
  );
}

/// The four destinations a phone needs most. Everything else is under More (the drawer).
const _primaryNav = [
  _NavItem('Overview', 'home', '/overview'),
  _NavItem('Accounts', 'account', '/accounts'),
  _NavItem('Property listings', 'listings', '/m/listings'),
];

class _BottomNav extends StatelessWidget {
  final String section;
  const _BottomNav({required this.section});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final idx = _primaryNav.indexWhere((n) => n.route == section);
    final sel = idx < 0 ? _primaryNav.length : idx;
    final count = _primaryNav.length + 1;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dx = (-1 + 2 * sel / (count - 1)) * (rtl ? -1 : 1);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        // The same frosted glass as the customer app's bar: the page shows through it.
        child: AQGlass(
          radius: 32,
          blur: 22,
          fill: 0.58,
          child: SizedBox(
            height: 64,
            child: Stack(children: [
              AnimatedAlign(
                duration: AQMotion.scaled(context, const Duration(milliseconds: 380)),
                curve: Curves.easeOutBack,
                alignment: Alignment(dx, 0),
                child: FractionallySizedBox(
                  widthFactor: 1 / count,
                  heightFactor: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(27),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                    ),
                  ),
                ),
              ),
              Row(children: [
                for (final n in _primaryNav) Expanded(child: _NavButton(icon: n.icon, label: tr(n.label == 'Property listings' ? 'Listings' : n.label), selected: section == n.route, onTap: () => context.go(n.route), bar: true)),
                Expanded(child: _NavButton(icon: 'more', label: tr('More'), selected: idx < 0, onTap: () => Scaffold.of(context).openDrawer(), bar: true)),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final String section;
  final VoidCallback onMore;
  const _Rail({required this.section, required this.onMore});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final inPrimary = _primaryNav.any((n) => n.route == section);
    return Container(
      width: 80,
      decoration: BoxDecoration(color: c.surfaceRaised, border: BorderDirectional(end: BorderSide(color: c.hairline))),
      child: Column(children: [
        const SizedBox(height: 8),
        for (final n in _primaryNav) SizedBox(height: 64, child: _NavButton(icon: n.icon, label: tr(n.label == 'Property listings' ? 'Listings' : n.label), selected: section == n.route, onTap: () => context.go(n.route))),
        SizedBox(height: 64, child: _NavButton(icon: 'more', label: tr('More'), selected: !inPrimary, onTap: onMore)),
      ]),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon, label;
  final bool selected;
  final VoidCallback onTap;
  final bool bar;
  const _NavButton({required this.icon, required this.label, required this.selected, required this.onTap, this.bar = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (bar)
            AnimatedScale(
              scale: selected ? 1.18 : 1,
              duration: AQMotion.scaled(context, const Duration(milliseconds: 320)),
              curve: Curves.easeOutBack,
              child: AnimatedSlide(
                offset: Offset(0, selected ? -0.08 : 0),
                duration: AQMotion.scaled(context, const Duration(milliseconds: 320)),
                curve: Curves.easeOutCubic,
                child: AQIcon(icon, size: 22, color: selected ? c.accentDeep : c.inkSoft),
              ),
            )
          else
          AnimatedContainer(
            duration: AQMotion.scaled(context, AQMotion.fast),
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: selected ? c.surfaceSelected : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: selected ? [BoxShadow(color: c.accent.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 3))] : const [],
            ),
            child: Center(child: AQIcon(icon, size: 20, color: selected ? c.accentDeep : c.inkSoft)),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelSmall, color: selected ? c.accentDeep : c.inkSoft).copyWith(letterSpacing: 0, wordSpacing: 0, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ]),
      ),
    );
  }
}

class _SideItem extends StatefulWidget {
  final _NavItem item;
  final bool selected, closeDrawer;
  const _SideItem({required this.item, required this.selected, this.closeDrawer = false});
  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hover = false;

  void _go() {
    if (widget.closeDrawer) Navigator.of(context).maybePop();
    context.go(widget.item.route);
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final selected = widget.selected;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        button: true,
        focusable: true,
        onFocus: () {},
        selected: selected,
        label: tr(widget.item.label),
        excludeSemantics: true,
        onTap: _go,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: AQPressable(
            onTap: _go,
            pressedScale: 0.99,
            child: AnimatedContainer(
              duration: AQMotion.scaled(context, const Duration(milliseconds: 260)),
              curve: Curves.easeOutCubic,
              height: 46,
              padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
              decoration: BoxDecoration(
                gradient: selected ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]) : null,
                color: selected ? null : (_hover ? c.accent.withValues(alpha: 0.08) : Colors.transparent),
                borderRadius: BorderRadius.circular(16),
                boxShadow: selected ? [BoxShadow(color: c.accent.withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 5))] : const [],
              ),
              child: Row(
                children: [
                  AnimatedContainer(
                    duration: AQMotion.scaled(context, const Duration(milliseconds: 260)),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: selected ? Colors.white.withValues(alpha: 0.2) : c.accent.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Center(child: AQIcon(widget.item.icon, size: 18, color: selected ? Colors.white : c.accentDeep)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AQTypography.of(context, AQText.titleSmall, color: selected ? Colors.white : c.ink).copyWith(
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      ),
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

// ------------------------------------------------------------------ table

class AdminTableRow {
  final String key;
  final List<Widget> cells;
  final String semantics;
  final VoidCallback? onTap;

  /// Indexes of cells that hold their own buttons. Those keep their own accessibility nodes, so a
  /// screen reader can reach "Pause" or "Move up" instead of only hearing the row as one button.
  final Set<int> actionCells;
  const AdminTableRow({
    required this.key,
    required this.cells,
    required this.semantics,
    this.onTap,
    this.actionCells = const {},
  });
}

/// A table on a wide page, and one card per record on a narrow page, so nothing is squeezed until it
/// stops being readable. [flex] sets the relative column widths.
// Each row (and, in the Ads list, each action) has a stable key, so when a row changes from
// Pause to Resume the accessibility node of its button is rebuilt instead of reusing the old one.
Widget _rowSemantics(AdminTableRow r, Widget child) => KeyedSubtree(
  key: ValueKey('row-${r.key}'),
  child: Semantics(
    container: true,
    explicitChildNodes: r.actionCells.isNotEmpty,
    button: r.onTap != null,
    focusable: r.onTap != null,
    onFocus: r.onTap == null ? null : () {},
    onTap: r.onTap,
    label: tr(r.semantics),
    excludeSemantics: r.actionCells.isEmpty,
    child: child,
  ),
);

Widget _cell(AdminTableRow r, int i) =>
    r.actionCells.isEmpty || r.actionCells.contains(i)
    ? r.cells[i]
    : ExcludeSemantics(child: r.cells[i]);

/// Previous / Page X of Y / Next as one quiet bar under a table. Same two actions as before.
class AdminPager extends StatelessWidget {
  final int page, pages;
  final VoidCallback? onPrevious, onNext;
  const AdminPager({super.key, required this.page, required this.pages, required this.onPrevious, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2, vertical: AQSpacing.x1),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
        child: Row(
          children: [
            AdminTextButton(label: tr('Previous'), color: c.accent, onPressed: onPrevious),
            Expanded(
              child: Center(child: Text('Page ${page + 1} of $pages', style: AQTypography.of(context, AQText.labelMedium, soft: true))),
            ),
            AdminTextButton(label: tr('Next'), color: c.accent, onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class AdminTable extends StatelessWidget {
  final List<String> headers;
  final List<int> flex;
  final List<AdminTableRow> rows;

  /// Columns of figures: header and values line up at the end edge.
  final Set<int> endColumns;
  const AdminTable({
    super.key,
    required this.headers,
    required this.flex,
    required this.rows,
    this.endColumns = const {},
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    if (!wide) {
      return Column(
        children: [
          const SizedBox(height: 12),
          for (final (ri, r) in rows.indexed)
            _Rise(
              index: ri % 8 + 1,
              child: Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: _rowSemantics(
                r,
                AQPressable(
                  onTap: r.onTap,
                  child: AQGlass(
                    radius: 24,
                    blur: 14,
                    fill: 0.66,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cell(r, 0),
                        if (r.cells.length > 1)
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(AdminSize.panel)),
                            // Fields sit two to a row, label over value; a cell with its own buttons
                            // takes the full width under them.
                            child: LayoutBuilder(
                              builder: (context, box) {
                                final half = (box.maxWidth - 12) / 2;
                                Widget field(int i) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(headers[i], style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint).copyWith(letterSpacing: 0.3)),
                                    const SizedBox(height: 3),
                                    Align(alignment: AlignmentDirectional.centerStart, child: _cell(r, i)),
                                  ],
                                );
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 12,
                                      runSpacing: 10,
                                      children: [
                                        for (var i = 1; i < r.cells.length; i++)
                                          if (!r.actionCells.contains(i)) SizedBox(width: half, child: field(i)),
                                      ],
                                    ),
                                    for (var i = 1; i < r.cells.length; i++)
                                      if (r.actionCells.contains(i)) Padding(padding: const EdgeInsets.only(top: 10), child: _cell(r, i)),
                                  ],
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
        ],
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AdminSize.panel + 6),
        border: Border.all(color: c.hairline),
        boxShadow: [BoxShadow(color: c.accentDeep.withValues(alpha: 0.08), blurRadius: 26, offset: const Offset(0, 10))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [c.surfaceSelected, c.surface])),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                for (var i = 0; i < headers.length; i++)
                  Expanded(
                    flex: flex[i],
                    child: Align(
                      alignment: endColumns.contains(i) ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                      child: Text(
                        headers[i],
                        style: AQTypography.of(
                          context,
                          AQText.labelMedium,
                          color: c.inkSoft,
                        ).copyWith(fontSize: 12, letterSpacing: 0.4),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final (ri, r) in rows.indexed)
            _Rise(
              index: ri % 8 + 1,
              child: _rowSemantics(
              r,
              AQPressable(
                onTap: r.onTap,
                pressedScale: 1,
                child: _HoverTint(
                  child: Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: c.hairline)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  constraints: const BoxConstraints(minHeight: 56),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < r.cells.length; i++)
                        Expanded(
                          flex: flex[i],
                          // A gutter after each column, so the end of one cell's text never meets the start of the next.
                          child: Padding(
                            padding: const EdgeInsetsDirectional.only(end: 12),
                            child: Align(
                              alignment: endColumns.contains(i) ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                              child: _cell(r, i),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ),
              ),
            ),
            ),
        ],
      ),
    ),
    );
  }
}

/// A row that tints softly under the pointer.
class _HoverTint extends StatefulWidget {
  final Widget child;
  const _HoverTint({required this.child});
  @override
  State<_HoverTint> createState() => _HoverTintState();
}

class _HoverTintState extends State<_HoverTint> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: AQMotion.scaled(context, const Duration(milliseconds: 180)),
        color: _h ? c.accent.withValues(alpha: 0.07) : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

Widget adminStatusPill(String label, (AQTone, String) look) =>
    AQStatusPill(label: tr(label), tone: look.$1, icon: look.$2, dense: true);

// ------------------------------------------------------------------ async + states

/// Loading skeleton, an error with Retry, or the data. A session that ended sends the person to
/// sign-in; a role that is not allowed sees a plain "not allowed" instead of an empty screen.
class AdminAsyncView<T> extends ConsumerWidget {
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;
  final double skeletonHeight;
  const AdminAsyncView({
    super.key,
    required this.value,
    required this.onRetry,
    required this.builder,
    this.skeletonHeight = 72,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) {
      final e = value.error!;
      if (e is AdminSessionExpiredException) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => ref.read(adminAuthProvider.notifier).expire(),
        );
        return const SizedBox.shrink();
      }
      if (e is AdminForbiddenException) {
        return AdminNotice(
          icon: 'lock',
          title: tr('Not allowed'),
          body: adminErrorText(e),
        );
      }
      return AQErrorBanner(
        text: tr('We could not load this. Check the connection and try again.'),
        action: AdminTextButton(
          label: tr('Try again'),
          color: c.accent,
          onPressed: onRetry,
        ),
      );
    }
    return Column(
      children: [for (var i = 0; i < 3; i++) _Skeleton(height: skeletonHeight)],
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return _Shimmer(height: height);
  }
}

/// A round icon with a soft halo that breathes, so empty and info states feel alive.
class _GlowIcon extends StatefulWidget {
  final String icon;
  const _GlowIcon({required this.icon});
  @override
  State<_GlowIcon> createState() => _GlowIconState();
}

class _GlowIconState extends State<_GlowIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _ctl.repeat(reverse: true, count: 20);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctl.value);
        return Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surfaceSelected, Color.alphaBlend(c.accent.withValues(alpha: 0.18), c.surfaceSelected)]),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.12 + 0.16 * t), blurRadius: 14 + 14 * t, spreadRadius: 2 * t)],
          ),
          child: Center(child: AQIcon(widget.icon, size: 28, color: c.accentDeep)),
        );
      },
    );
  }
}

class AdminNotice extends StatelessWidget {
  final String icon, title, body;
  final Widget? action;
  const AdminNotice({
    super.key,
    this.icon = 'info',
    required this.title,
    this.body = '',
    this.action,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(c.accent.withValues(alpha: 0.07), c.surfaceRaised), c.surfaceRaised]),
        borderRadius: BorderRadius.circular(AdminSize.panel + 6),
        border: Border.all(color: c.hairline),
        boxShadow: [BoxShadow(color: c.accentDeep.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(
        children: [
          _GlowIcon(icon: icon),
          const SizedBox(height: 14),
          Semantics(
            header: true,
            child: Text(title, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.titleMedium)),
          ),
          if (body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Text(body, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              ),
            ),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 14), child: action!),
        ],
      ),
    );
  }
}

class AdminKeyValues extends StatelessWidget {
  final List<(String, String)> rows;
  const AdminKeyValues(this.rows, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AdminPanel(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (final (i, r) in rows.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              decoration: BoxDecoration(
                color: i.isEven ? c.accent.withValues(alpha: 0.045) : Colors.transparent,
                border: BorderDirectional(start: BorderSide(color: i.isEven ? c.accent.withValues(alpha: 0.5) : Colors.transparent, width: 3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: (MediaQuery.sizeOf(context).width * 0.36).clamp(96.0, 148.0), child: Padding(padding: const EdgeInsetsDirectional.only(end: 8), child: Text(r.$1, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft)))),
                  Expanded(child: Text(VFmt.iso(r.$2), style: AQTypography.of(context, AQText.bodyMedium))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

Widget adminSection(BuildContext context, String title, {Widget? trailing}) =>
    Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Row(children: [
                Container(width: 4, height: 22, margin: const EdgeInsetsDirectional.only(end: 10), decoration: BoxDecoration(color: AQColors.of(context).accent, borderRadius: BorderRadius.circular(2))),
                Expanded(child: Text(title, style: AQTypography.of(context, AQText.headlineSmall))),
              ]),
            ),
          ),
          ?trailing,
        ],
      ),
    );

Widget adminDemoNotice() => kUseDemoBackend
    ? const Padding(
        padding: EdgeInsets.only(top: AQSpacing.x4),
        child: AQDemoNotice(),
      )
    : const SizedBox.shrink();

// ------------------------------------------------------------------ document viewer

/// Shows a document the service streams. Documents are never downloaded or stored here: the viewer
/// only displays the stream, with a watermark of who is looking and when. There is no real file in
/// the demo, and the dialog says so.
Future<void> showDocumentViewer(
  BuildContext context,
  WidgetRef ref,
  AdminDocument doc,
) {
  final session = ref.read(adminAuthProvider).session;
  return showDialog<void>(
    context: context,
    builder: (d) {
      final c = AQColors.of(d);
      final stamp =
          '${session?.name ?? 'Admin'} · ${session?.id ?? ''} · ${DateTime.now().toIso8601String().substring(0, 16).replaceAll('T', ' ')}';
      return _AdminDialog(
        backgroundColor: c.surfaceRaised,
        insetPadding: const EdgeInsets.all(AQSpacing.x4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AQRadius.large),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(AQSpacing.x5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          doc.label,
                          style: AQTypography.of(d, AQText.headlineSmall),
                        ),
                      ),
                    ),
                    AQIconButton(
                      icon: 'close',
                      semanticsLabel: tr('Close'),
                      onPressed: () => Navigator.of(d).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: AQSpacing.x3),
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AQRadius.medium),
                    child: Container(
                      height: 320,
                      color: c.surface,
                      child: doc.available
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(AQSpacing.x5),
                                  child: Text(
                                    'Demo document. There is no real file behind this preview.',
                                    textAlign: TextAlign.center,
                                    style: AQTypography.of(
                                      d,
                                      AQText.bodyMedium,
                                      soft: true,
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: Transform.rotate(
                                        angle: -0.35,
                                        child: Text(
                                          '$stamp\n$stamp\n$stamp',
                                          textAlign: TextAlign.center,
                                          style: AQTypography.of(
                                            d,
                                            AQText.labelMedium,
                                            color: c.ink.withValues(
                                              alpha: 0.16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.all(AQSpacing.x5),
                              child: Center(
                                child: AdminNotice(
                                  icon: 'alert',
                                  title: tr('This document is not available'),
                                  body: tr('The service could not stream it. It may be missing, expired or removed. Ask the applicant to resubmit it.'),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AQSpacing.x3),
                Text(
                  'Viewing is recorded. The file cannot be downloaded or saved from this screen.',
                  style: AQTypography.of(
                    d,
                    AQText.bodySmall,
                    color: c.inkFaint,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ------------------------------------------------------------------ step-up and decisions

/// Asks for a fresh one-time code before a decision (step-up re-authentication). Returns true only
/// when the service accepted it.
Future<bool> showStepUp(BuildContext context, WidgetRef ref) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (d) => _StepUpDialog(ref: ref),
  );
  return ok == true;
}

class _StepUpDialog extends StatefulWidget {
  final WidgetRef ref;
  const _StepUpDialog({required this.ref});
  @override
  State<_StepUpDialog> createState() => _StepUpDialogState();
}

class _StepUpDialogState extends State<_StepUpDialog> {
  AQOtpState _state = AQOtpState.idle;
  String? _error;
  final _key = GlobalKey<AQOtpFieldState>();

  Future<void> _submit(String code) async {
    setState(() {
      _state = AQOtpState.verifying;
      _error = null;
    });
    try {
      await widget.ref.read(adminAuthRepositoryProvider).reauthenticate(code);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (endSessionIfExpired(widget.ref, e)) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      if (mounted) {
        setState(() {
          _state = AQOtpState.error;
          _error = e is AdminTotpException
              ? 'That code is not right. Try the current code.'
              : 'We could not check the code. Try again.';
        });
        _key.currentState?.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return _AdminDialog(
      backgroundColor: c.surfaceRaised,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AQRadius.large),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AQSpacing.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Confirm it is you',
                  style: AQTypography.of(context, AQText.headlineSmall),
                ),
              ),
              const SizedBox(height: AQSpacing.x2),
              Text(
                'Enter the current code from your authenticator app to record this decision.',
                style: AQTypography.of(context, AQText.bodyMedium, soft: true),
              ),
              const SizedBox(height: AQSpacing.x4),
              AQOtpField(
                key: _key,
                label: tr('One-time code'),
                state: _state,
                enabled: _state != AQOtpState.verifying,
                onCompleted: _submit,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x3),
                  child: AQErrorBanner(text: tr(_error!)),
                ),
              const SizedBox(height: AQSpacing.x4),
              AdminSecondaryButton(
                label: tr('Cancel'),
                trailingChevron: false,
                onPressed: _state == AQOtpState.verifying
                    ? null
                    : () => Navigator.of(context).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The decision form shared by verification and moderation: choose Approve, Request resubmission or
/// Reject; a reason code (and a note for "Other") is required for the last two; a fresh one-time
/// code confirms it. Nothing is sent until every required part is there, and a failure leaves the
/// item exactly as it was.
class DecisionPanel extends ConsumerStatefulWidget {
  final List<ReasonCode> reasons;

  /// Null when approving is allowed; otherwise the reason it is not.
  final String? approveBlockedReason;
  final bool canDecide;
  final bool open;
  final Future<void> Function(Decision d, ReasonCode? reason, String note)
  onDecide;
  const DecisionPanel({
    super.key,
    required this.reasons,
    this.approveBlockedReason,
    required this.canDecide,
    required this.open,
    required this.onDecide,
  });
  @override
  ConsumerState<DecisionPanel> createState() => _DecisionPanelState();
}

class _DecisionPanelState extends ConsumerState<DecisionPanel> {
  Decision? _decision;
  ReasonCode? _reason;
  final _note = TextEditingController();
  bool _tried = false, _busy = false;
  String? _error, _done;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _needsReason => _decision != null && _decision != Decision.approve;

  String? get _reasonError =>
      _tried && _needsReason && _reason == null ? 'Choose a reason.' : null;
  String? get _noteError =>
      _tried &&
          _needsReason &&
          _reason == ReasonCode.other &&
          _note.text.trim().isEmpty
      ? 'Add a note for "Other".'
      : null;

  Future<void> _submit() async {
    setState(() => _tried = true);
    final d = _decision;
    if (d == null || _busy) return;
    if (d == Decision.approve && widget.approveBlockedReason != null) return;
    if (_needsReason &&
        (_reason == null ||
            (_reason == ReasonCode.other && _note.text.trim().isEmpty))) {
      return;
    }
    final ok = await showStepUp(context, ref);
    if (!ok || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
    });
    try {
      await widget.onDecide(
        d,
        _needsReason ? _reason : null,
        _note.text.trim(),
      );
      if (mounted) {
        setState(() {
          _done = switch (d) {
            Decision.approve => 'Decision recorded: approved.',
            Decision.requestResubmission =>
              'Decision recorded: resubmission requested.',
            Decision.reject => 'Decision recorded: rejected.',
          };
          _decision = null;
          _reason = null;
          _note.clear();
          _tried = false;
        });
      }
    } catch (e) {
      if (!endSessionIfExpired(ref, e) && mounted) {
        setState(() => _error = adminErrorText(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    if (!widget.canDecide) {
      return AdminNotice(
        icon: 'lock',
        title: tr('Read-only'),
        body: tr('Your role can view this item but not decide it.'),
      );
    }
    if (!widget.open) {
      return Column(
        children: [
          if (_done != null)
            AQErrorBanner(tone: AQBannerTone.success, text: tr(_done!)),
          AdminNotice(
            icon: 'check',
            title: tr('Decided'),
            body: tr('This item has been decided. Its status is shown above.'),
          ),
        ],
      );
    }
    final blocked = _decision == Decision.approve
        ? widget.approveBlockedReason
        : null;
    return AdminPanel(
      padding: const EdgeInsets.all(AQSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Decision',
              style: AQTypography.of(context, AQText.titleMedium),
            ),
          ),
          const SizedBox(height: AQSpacing.x3),
          adminChoiceRow([
            for (final d in Decision.values)
              (decisionLabel(d), _decision == d, () => setState(() => _decision = d)),
          ]),
          AnimatedSize(
            duration: AQMotion.scaled(context, AQMotion.fast),
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (blocked != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AQSpacing.x3),
                    child: AQErrorBanner(
                      tone: AQBannerTone.info,
                      text: tr(blocked),
                    ),
                  ),
                if (_needsReason) ...[
                  const SizedBox(height: AQSpacing.x4),
                  DbSelectField<ReasonCode>(
                    label: tr('Reason code'),
                    valueLabel: _reason == null ? null : reasonLabel(_reason!),
                    hint: tr('Choose a reason'),
                    required: true,
                    error: null,
                    onTap: () async {
                      final r = await showDbChoiceSheet<ReasonCode>(
                        context,
                        title: tr('Reason code'),
                        options: [
                          for (final x in widget.reasons) (x, reasonLabel(x)),
                        ],
                        selected: _reason,
                      );
                      if (r != null) setState(() => _reason = r);
                    },
                  ),
                  if (_reasonError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AQSpacing.x1),
                      child: Text(
                        _reasonError!,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          color: c.danger,
                        ),
                      ),
                    ),
                  const SizedBox(height: AQSpacing.x3),
                  AdminField(
                    label: _reason == ReasonCode.other
                        ? 'Note (required)'
                        : 'Note for the applicant (optional)',
                    controller: _note,
                    minLines: 2,
                    maxLines: 5,
                    keyboardType: TextInputType.multiline,
                    action: TextInputAction.newline,
                    error: _noteError,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x3),
              child: AQErrorBanner(text: tr(_error!)),
            ),
          if (_done != null)
            Padding(
              padding: const EdgeInsets.only(top: AQSpacing.x3),
              child: AQErrorBanner(tone: AQBannerTone.success, text: tr(_done!)),
            ),
          const SizedBox(height: AQSpacing.x4),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AdminPrimaryButton(
                label: _decision == null
                    ? 'Choose a decision'
                    : decisionLabel(_decision!),
                trailingChevron: false,
                loading: _busy,
                onPressed: _decision == null || _busy || blocked != null
                    ? null
                    : _submit,
              ),
          ),
        ],
      ),
    );
  }
}

/// Wraps a pending claim: takes the lock when the page opens and gives it back when it closes.
class ClaimBanner extends StatelessWidget {
  final String? lockedBy;
  const ClaimBanner({super.key, this.lockedBy});
  @override
  Widget build(BuildContext context) {
    if (lockedBy == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x4),
      child: AQErrorBanner(
        tone: AQBannerTone.info,
        text: tr('$lockedBy is reviewing this item. You can read it, but decisions are locked until they finish or 30 minutes pass.'),
      ),
    );
  }
}

String shortDate(BuildContext context, DateTime d) =>
    '${VFmt.shortDate(context, d)} · ${VFmt.time(context, d)}';

/// Used by the queue pages: a simple text filter field.
class AdminSearchField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
  });
  @override
  State<AdminSearchField> createState() => _AdminSearchFieldState();
}

class _AdminSearchFieldState extends State<AdminSearchField> {
  bool _focus = false;
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        // The field lifts and glows while you type.
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (v) => setState(() => _focus = v),
          child: AnimatedContainer(
            duration: AQMotion.scaled(context, const Duration(milliseconds: 260)),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: _focus ? 0.30 : 0.08), blurRadius: _focus ? 22 : 10, offset: Offset(0, _focus ? 8 : 3))],
            ),
            child: AdminField(
              label: widget.hint,
              controller: widget.controller,
              hint: tr('Type to search'),
              action: TextInputAction.search,
              prefix: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12),
                child: AQIcon('search', size: 18, color: _focus ? c.accentDeep : c.inkSoft),
              ),
              onChanged: widget.onChanged,
            ),
          ),
        ),
      ),
    );
  }
}

/// A labelled row of small filter chips. The label sits beside the chips, so a toolbar of several
/// filters stays two or three lines high.
Widget adminFilterRow(
  BuildContext context,
  String label,
  List<(String, bool, VoidCallback)> pills,
) {
  final narrow = MediaQuery.sizeOf(context).width < 720;
  return Padding(
    padding: const EdgeInsets.only(top: 12),
    child: narrow
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(tr(label), style: AQTypography.of(context, AQText.labelMedium, soft: true))),
              _chipLine(context, pills),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 72, child: Padding(padding: const EdgeInsets.only(top: 6), child: Text(tr(label), style: AQTypography.of(context, AQText.labelMedium, soft: true)))),
              Expanded(child: _chipLine(context, pills)),
            ],
          ),
  );
}

/// Filter chips always wrap onto as many lines as they need: on a phone no label is ever cut off.
Widget _chipLine(BuildContext context, List<(String, bool, VoidCallback)> pills) {
  final chips = [for (final p in pills) AdminChip(label: p.$1, selected: p.$2, onTap: p.$3)];
  if (MediaQuery.sizeOf(context).width >= 720) return Wrap(spacing: 6, runSpacing: 6, children: chips);
  // On a phone every filter is one swipeable line, so the list is never pushed off the screen.
  return SizedBox(
    height: 40,
    child: ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => const LinearGradient(colors: [Colors.black, Colors.black, Colors.transparent], stops: [0, 0.9, 1]).createShader(r),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.only(end: 28),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    ),
  );
}

/// A wrapped row of choice chips, for forms.
Widget adminChoiceRow(List<(String, bool, VoidCallback)> pills) => Wrap(
  spacing: 6,
  runSpacing: 6,
  children: [for (final p in pills) AdminChip(label: p.$1, selected: p.$2, onTap: p.$3)],
);

/// A dialog whose children keep their own accessibility nodes (so the close button and the code field
/// can be reached with a screen reader or by label), not merged into one "dialog" node.
class _AdminDialog extends StatelessWidget {
  final Color backgroundColor;
  final EdgeInsets insetPadding;
  final ShapeBorder shape;
  final Widget child;
  const _AdminDialog({
    required this.backgroundColor,
    this.insetPadding = const EdgeInsets.symmetric(
      horizontal: 40,
      vertical: 24,
    ),
    required this.shape,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: backgroundColor,
    insetPadding: insetPadding,
    shape: shape,
    child: Semantics(container: true, explicitChildNodes: true, child: child),
  );
}


/// Switches the console (and the rest of the app) between English and Arabic. It shows the other
/// language's own name, so it is findable whichever language is on.
class AdminLangButton extends ConsumerWidget {
  const AdminLangButton({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final ar = ref.watch(localeProvider).languageCode == 'ar';
    return AdminTextButton(
      key: const ValueKey('admin-lang'),
      label: ar ? 'English' : 'العربية',
      color: c.accentDeep,
      onPressed: () => ref.read(localeProvider.notifier).state = Locale(ar ? 'en' : 'ar'),
    );
  }
}

/// A rich header card: deep espresso gradient, slow drifting light, a big counting number and quick links.
class AdminHero extends StatefulWidget {
  final String eyebrow, headline, caption;
  final int number;
  final List<(String, String, VoidCallback)> links;
  const AdminHero({super.key, required this.eyebrow, required this.headline, required this.caption, required this.number, this.links = const []});
  @override
  State<AdminHero> createState() => _AdminHeroState();
}

class _AdminHeroState extends State<AdminHero> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(seconds: 9));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _ctl.repeat(reverse: true, count: 12);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const gold = Color(0xFFE9C9A0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF2B1F16), Color(0xFF5A3F2A), Color(0xFF825C3F)]),
        ),
        child: Stack(children: [
          // Two soft lights that drift, so the card is never still.
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ctl,
              builder: (context, _) {
                final t = Curves.easeInOut.transform(_ctl.value);
                return Stack(children: [
                  Positioned(right: -60 + 50 * t, top: -70 + 30 * t, child: _orb(220, gold.withValues(alpha: 0.30))),
                  Positioned(left: -80 + 40 * (1 - t), bottom: -110 + 20 * t, child: _orb(240, const Color(0xFFB8845A).withValues(alpha: 0.35))),
                ]);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.eyebrow.toUpperCase(), style: AQTypography.of(context, AQText.labelSmall, color: gold).copyWith(letterSpacing: 1.6)),
              const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: widget.number.toDouble()),
                  duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 1100),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ','), style: AQTypography.of(context, AQText.displayLarge, color: Colors.white).copyWith(height: 1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(widget.headline, style: AQTypography.of(context, AQText.titleMedium, color: Colors.white)),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(widget.caption, style: AQTypography.of(context, AQText.bodySmall, color: Colors.white.withValues(alpha: 0.78))),
              if (widget.links.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final l in widget.links)
                    Semantics(
                      button: true,
                      label: l.$1,
                      excludeSemantics: true,
                      onTap: l.$3,
                      child: AQPressable(
                        onTap: l.$3,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 40),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(l.$1, style: AQTypography.of(context, AQText.labelMedium, color: Colors.white)),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(color: gold, borderRadius: BorderRadius.circular(10)),
                              child: Text(l.$2, style: AQTypography.of(context, AQText.labelSmall, color: const Color(0xFF2B1F16)).copyWith(letterSpacing: 0.2)),
                            ),
                          ]),
                        ),
                      ),
                    ),
                ]),
              ],
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _orb(double size, Color color) => IgnorePointer(
    child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]))),
  );
}

/// A strip of frosted tiles with numbers that count up. Sits under a screen's title.
class AdminStatStrip extends StatelessWidget {
  final List<(String, int)> stats;
  const AdminStatStrip(this.stats, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        for (final (i, s) in stats.indexed) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: AQGlass(
              radius: 20,
              blur: 12,
              fill: 0.62,
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: s.$2.toDouble()),
                  duration: still ? Duration.zero : Duration(milliseconds: 800 + 120 * i),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text('${v.round()}', style: AQTypography.of(context, AQText.headlineLarge, color: c.accentDeep)),
                ),
                const SizedBox(height: 2),
                Text(s.$1, maxLines: 2, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft).copyWith(letterSpacing: 0.1)),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// The signed-in person as a small glass card with a gradient monogram.
class _ProfileCard extends StatelessWidget {
  final String name, role;
  const _ProfileCard({required this.name, required this.role});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return _Rise(
      index: 1,
      child: AQGlass(
        radius: 22,
        blur: 10,
        fill: 0.7,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]),
              boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            alignment: Alignment.center,
            child: AQIcon('account', size: 22, color: c.onAccent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
              Text(role, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Loading placeholder with a light sweeping across it.
class _Shimmer extends StatefulWidget {
  final double height;
  const _Shimmer({required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  bool _started = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && !MediaQuery.disableAnimationsOf(context)) {
      _started = true;
      _ctl.repeat(count: 40);
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (context, _) => Container(
          height: widget.height,
          margin: const EdgeInsets.only(bottom: AQSpacing.x3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment(-1.6 + 3.2 * _ctl.value, 0),
              end: Alignment(-0.6 + 3.2 * _ctl.value, 0),
              colors: [c.accent.withValues(alpha: 0.06), c.accent.withValues(alpha: 0.16), c.accent.withValues(alpha: 0.06)],
            ),
          ),
        ),
      ),
    );
  }
}

/// A frosted metric tile: icon, a number that counts up, a label.
class AdminMetricTile extends StatelessWidget {
  final String label, value, icon;
  final bool sample;
  const AdminMetricTile({super.key, required this.label, required this.value, required this.icon, this.sample = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final n = int.tryParse(value.replaceAll(',', ''));
    final still = MediaQuery.disableAnimationsOf(context);
    return AQGlass(
      radius: 24,
      blur: 12,
      fill: 0.66,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent.withValues(alpha: 0.22), c.accent.withValues(alpha: 0.08)]),
          ),
          child: Center(child: AQIcon(icon, size: 18, color: c.accentDeep)),
        ),
        const SizedBox(height: 12),
        n == null
            ? Text(value, style: AQTypography.of(context, AQText.headlineMedium))
            : TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: n.toDouble()),
                duration: still ? Duration.zero : const Duration(milliseconds: 1000),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) {
                  final t = v.round().toString();
                  final shown = value.contains(',') ? t.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',') : t;
                  return Text(shown, style: AQTypography.of(context, AQText.headlineMedium));
                },
              ),
        const SizedBox(height: 2),
        Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        if (sample) Padding(padding: const EdgeInsets.only(top: 4), child: Text('Sample figure', style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep).copyWith(letterSpacing: 0.2))),
      ]),
    );
  }
}

/// Columns that grow up from the baseline, one after another.
class AdminBarChart extends StatelessWidget {
  final List<int> values;
  final String Function(int index) labelOf;
  const AdminBarChart({super.key, required this.values, required this.labelOf});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    final max = values.fold<int>(1, (m, v) => v > m ? v : m);
    return SizedBox(
      height: 190,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final (i, v) in values.indexed)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: v / max),
                duration: still ? Duration.zero : Duration(milliseconds: 700 + 90 * i),
                curve: Curves.easeOutBack,
                builder: (context, f, _) => Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text('$v', style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep).copyWith(letterSpacing: 0.2)),
                  const SizedBox(height: 4),
                  Container(
                    height: 130 * f.clamp(0.0, 1.1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c.accent, c.accentDeep]),
                      boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(labelOf(i), style: AQTypography.of(context, AQText.labelSmall, color: c.inkSoft).copyWith(letterSpacing: 0.2)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

/// "3 of 4" with a bar that fills smoothly.
class AdminProgressCard extends StatelessWidget {
  final String label;
  final int done, total;
  const AdminProgressCard({super.key, required this.label, required this.done, required this.total});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final still = MediaQuery.disableAnimationsOf(context);
    return AQGlass(
      radius: 22,
      blur: 10,
      fill: 0.68,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(label, style: AQTypography.of(context, AQText.titleSmall))),
          Text('$done / $total', style: AQTypography.of(context, AQText.titleSmall, color: c.accentDeep)),
        ]),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
            duration: still ? Duration.zero : const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 10, color: done == total ? c.success : c.accent, backgroundColor: c.accent.withValues(alpha: 0.14)),
          ),
        ),
      ]),
    );
  }
}

/// Big profile header for Settings: gradient badge, name, role, on a glass card.
class AdminProfileHeader extends StatelessWidget {
  final String name, role;
  const AdminProfileHeader({super.key, required this.name, required this.role});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AQGlass(
      radius: 30,
      blur: 14,
      fill: 0.68,
      padding: const EdgeInsets.all(20),
      child: Row(children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.accent, c.accentDeep]),
            boxShadow: [BoxShadow(color: c.accent.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Center(child: AQIcon('account', size: 34, color: c.onAccent)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.headlineSmall)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: c.accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Text(role, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep).copyWith(letterSpacing: 0.1)),
            ),
          ]),
        ),
      ]),
    );
  }
}
