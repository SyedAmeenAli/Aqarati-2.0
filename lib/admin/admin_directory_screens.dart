import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_primitives.dart';
import '../core/aq/aq_tokens.dart';
import '../core/aq/aq_typography.dart';
import '../features/viewing/domain/viewing_presentation.dart' show AQTone;
import '../features/viewing/widgets/viewing_format.dart';
import '../features/ads/ad_models.dart';
import '../features/ads/sponsored_banner.dart' show SponsoredBannerView;
import 'admin_auth.dart';
import 'admin_directory.dart';
import 'admin_models.dart';
import 'admin_repository.dart';
import 'admin_images.dart';
import 'admin_widgets.dart';
import 'admin_ui.dart';
import 'admin_l10n.dart';

String _actor(WidgetRef ref) => ref.read(adminAuthProvider).session?.name ?? 'Admin';
bool _canDecide(WidgetRef ref) => ref.watch(adminAuthProvider).session?.role.canDecide ?? false;

String _date(BuildContext c, DateTime d) => '${VFmt.shortDate(c, d)}, ${VFmt.time(c, d)}';

(AQTone, String) _acctLook(AcctStatus s) => switch (s) {
  AcctStatus.active => (AQTone.success, 'check'),
  AcctStatus.underReview => (AQTone.pending, 'clock'),
  AcctStatus.suspended => (AQTone.danger, 'lock'),
  AcctStatus.rejected => (AQTone.neutral, 'close'),
};

(AQTone, String) _reportLook(ReportStatus s) => switch (s) {
  ReportStatus.open => (AQTone.warning, 'alert'),
  ReportStatus.inReview => (AQTone.pending, 'clock'),
  ReportStatus.resolved => (AQTone.success, 'check'),
  ReportStatus.dismissed => (AQTone.neutral, 'close'),
};

/// A confirmation: what will happen, in one or two lines, and two content-sized buttons. A
/// destructive action gets the restrained red treatment.
Future<bool> adminConfirm(BuildContext context, {required String title, required String body, required String action}) async {
  const destructive = ['suspend', 'reject', 'remove', 'delete', 'dismiss', 'cancel request'];
  final danger = destructive.any((w) => action.toLowerCase().startsWith(w));
  final c = AQColors.of(context);
  final yes = await showDialog<bool>(
    context: context,
    builder: (d) => Dialog(
      backgroundColor: c.surfaceRaised,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminSize.panel), side: BorderSide(color: c.hairline)),
      child: Semantics(
        scopesRoute: true,
        namesRoute: true,
        explicitChildNodes: true,
        label: tr(title),
        child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: AQTypography.of(d, AQText.titleLarge))),
              const SizedBox(height: 8),
              Text(body, style: AQTypography.of(d, AQText.bodyMedium, soft: true)),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AdminSecondaryButton(label: tr('Cancel'), onPressed: () => Navigator.of(d).pop(false)),
                    danger
                        ? AdminDangerButton(label: action, onPressed: () => Navigator.of(d).pop(true))
                        : AdminPrimaryButton(label: action, onPressed: () => Navigator.of(d).pop(true)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    ),
  );
  return yes == true;
}

// ------------------------------------------------------------------ overview

class AdminOverviewScreen extends ConsumerWidget {
  const AdminOverviewScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final dir = ref.watch(adminDirectoryProvider);
    final verif = ref.watch(verificationListProvider).valueOrNull;
    final listings = ref.watch(moderationListProvider).valueOrNull;
    final ads = ref.watch(adminAdsProvider).valueOrNull;
    int count(AcctStatus s) => dir.accounts.where((a) => a.status == s).length;
    final openReports = dir.reports.where((r) => r.status == ReportStatus.open || r.status == ReportStatus.inReview).length;
    final pendingListings = listings?.where((l) => l.status == ModerationStatus.pending).length;

    Widget metric(String label, String value, String route) => Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: tr('$label: $value'),
      excludeSemantics: true,
      onTap: () => context.go(route),
      child: AQPressable(
        onTap: () => context.go(route),
        pressedScale: 0.99,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surfaceRaised, Color.alphaBlend(c.accent.withValues(alpha: 0.07), c.surfaceRaised)]),
            borderRadius: BorderRadius.circular(AdminSize.panel + 4),
            border: Border.all(color: c.hairline),
            boxShadow: [BoxShadow(color: c.accentDeep.withValues(alpha: 0.07), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    int.tryParse(value) == null
                        ? Text(value, style: AQTypography.of(context, AQText.headlineLarge))
                        : TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: int.parse(value).toDouble()),
                            duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Text('${v.round()}', style: AQTypography.of(context, AQText.headlineLarge)),
                          ),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 4, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c.surfaceSelected, Color.alphaBlend(c.accent.withValues(alpha: 0.2), c.surfaceSelected)]),
                ),
                child: Center(
                  child: AQIcon(
                    switch (route) {
                      '/verification' => 'verified',
                      '/moderation' => 'shield',
                      '/reports' => 'flag',
                      '/ads' => 'megaphone',
                      _ => 'account',
                    },
                    size: 16,
                    color: c.accentDeep,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Widget queueRow(String icon, String label, String? count, String route) => Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: tr('$label${count == null ? '' : ': $count'}'),
      excludeSemantics: true,
      onTap: () => context.go(route),
      child: AQPressable(
        onTap: () => context.go(route),
        pressedScale: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              AQIcon(icon, size: 18, color: c.inkSoft),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AQTypography.of(context, AQText.bodyMedium))),
              if (count != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(6)),
                  child: Text(count, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)),
                ),
              const SizedBox(width: 8),
              AQIcon('chevron-right', size: 16, color: c.inkFaint, directional: true),
            ],
          ),
        ),
      ),
    );

    final byRole = {for (final r in AcctRole.values) r: dir.accounts.where((a) => a.role == r).length};
    final maxRole = byRole.values.fold<int>(1, (m, v) => v > m ? v : m);
    final live = ads?.where((a) => a.status == AdStatus.approved).toList() ?? const <SponsoredAd>[];
    final paused = ads?.where((a) => a.status == AdStatus.paused).length ?? 0;
    final waiting = ads?.where((a) => a.status == AdStatus.pendingVerification).length ?? 0;

    final queue = AdminPanel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          queueRow('account', 'Review accounts waiting for a decision', '${count(AcctStatus.underReview)}', '/accounts'),
          Divider(height: 1, thickness: 1, color: c.hairline),
          queueRow('verified', 'Decide verification applications', verif == null ? null : '${verif.length}', '/verification'),
          Divider(height: 1, thickness: 1, color: c.hairline),
          queueRow('shield', 'Moderate new listing submissions', pendingListings == null ? null : '$pendingListings', '/moderation'),
          Divider(height: 1, thickness: 1, color: c.hairline),
          queueRow('flag', 'Handle open complaints', '$openReports', '/reports'),
        ],
      ),
    );

    final activity = AdminTable(
      headers: const ['When', 'Who', 'Action', 'Record'],
      flex: const [4, 5, 5, 5],
      rows: [
        for (final (i, e) in dir.audit.take(6).indexed)
          AdminTableRow(
            key: 'ov$i',
            semantics: '${e.actor}, ${e.text}, ${e.target ?? ''}',
            cells: [
              Text(_date(context, e.at), style: AQTypography.of(context, AQText.bodySmall)),
              Text(e.actor, maxLines: 3, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall)),
              Text(e.text, maxLines: 3, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall)),
              Text(e.target ?? '', maxLines: 3, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall)),
            ],
          ),
      ],
    );

    final sponsored = AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ads == null ? 'Loading placements' : '${live.length} live, $paused paused, $waiting waiting for review',
            style: AQTypography.of(context, AQText.bodySmall, soft: true),
          ),
          if (live.isNotEmpty) ...[
            const SizedBox(height: 12),
            SponsoredBannerView(ads: [live.first], onTap: (_) => context.go('/ads')),
          ],
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AdminSecondaryButton(label: tr('Manage placements'), compact: true, onPressed: () => context.go('/ads')),
          ),
        ],
      ),
    );

    final roles = AdminPanel(
      child: Column(
        children: [
          for (final e in byRole.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(width: 176, child: Padding(padding: const EdgeInsetsDirectional.only(end: 10), child: Text(roleName(e.key), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall)))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(value: e.value / maxRole, minHeight: 6, color: c.accent, backgroundColor: c.hairline),
                    ),
                  ),
                  SizedBox(width: 28, child: Text('${e.value}', textAlign: TextAlign.end, style: AQTypography.of(context, AQText.labelMedium))),
                ],
              ),
            ),
        ],
      ),
    );

    return AdminFrame(
      section: '/overview',
      title: tr('Overview'),
      subtitle: tr('What needs attention across AQARATI. Demo data only.'),
      children: [
        AdminHero(
          eyebrow: tr('Today at AQARATI'),
          number: count(AcctStatus.underReview) + (verif?.length ?? 0) + (pendingListings ?? 0) + openReports,
          headline: tr('items need a decision'),
          caption: tr('Everything waiting for you, in one place. Demo data only.'),
          links: [
            (tr('Accounts'), '${count(AcctStatus.underReview)}', () => context.go('/accounts')),
            (tr('Verification'), '${verif?.length ?? 0}', () => context.go('/verification')),
            (tr('Listings'), '${pendingListings ?? 0}', () => context.go('/moderation')),
            (tr('Reports'), '$openReports', () => context.go('/reports')),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final cols = box.maxWidth >= 860 ? 3 : 2;
            const gap = 12.0;
            final w = (box.maxWidth - gap * (cols - 1)) / cols;
            Widget cell(Widget m) => SizedBox(width: w, child: m);
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                cell(metric('Accounts', '${dir.accounts.length}', '/accounts')),
                cell(metric('Accounts under review', '${count(AcctStatus.underReview)}', '/accounts')),
                cell(metric('Applications in the verification queue', verif == null ? '...' : '${verif.length}', '/verification')),
                cell(metric('Listings waiting for moderation', pendingListings == null ? '...' : '$pendingListings', '/moderation')),
                cell(metric('Open reports and complaints', '$openReports', '/reports')),
                cell(metric('Sponsored placements', ads == null ? '...' : '${ads.length}', '/ads')),
              ],
            );
          },
        ),
        LayoutBuilder(
          builder: (context, box) {
            final twoCol = box.maxWidth >= 900;
            final left = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                adminSection(context, 'Needs attention'),
                queue,
                adminSection(context, 'Recent administrative activity', trailing: AdminTextButton(label: tr('Open the log'), color: c.accentDeep, onPressed: () => context.go('/audit'))),
                activity,
              ],
            );
            final right = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                adminSection(context, 'Sponsored placements'),
                sponsored,
                adminSection(context, 'Accounts by role'),
                roles,
              ],
            );
            if (!twoCol) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [left, right]);
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: left),
                const SizedBox(width: 24),
                Expanded(flex: 4, child: right),
              ],
            );
          },
        ),
        adminDemoNotice(),
      ],
    );
  }
}

// ------------------------------------------------------------------ accounts

class AdminAccountsScreen extends ConsumerStatefulWidget {
  const AdminAccountsScreen({super.key});
  @override
  ConsumerState<AdminAccountsScreen> createState() => _AccountsState();
}

class _AccountsState extends ConsumerState<AdminAccountsScreen> {
  final _q = TextEditingController();
  AcctRole? _role;
  AcctStatus? _status;
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = ref.watch(adminDirectoryProvider);
    final shown = filterAccounts(dir.accounts, query: _q.text, role: _role, status: _status);
    return AdminFrame(
      section: '/accounts',
      title: tr('Accounts and professionals'),
      subtitle: tr('Shoppers, agents, developers, builders, architects and designers.'),
      children: [
        AdminSearchField(controller: _q, hint: tr('Search name, city or role'), onChanged: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x3),
        adminFilterRow(context, 'Role', [
          ('All', _role == null, () => setState(() => _role = null)),
          for (final r in AcctRole.values) (roleName(r), _role == r, () => setState(() => _role = _role == r ? null : r)),
        ]),
        adminFilterRow(context, 'Status', [
          ('All', _status == null, () => setState(() => _status = null)),
          for (final s in AcctStatus.values) (acctStatusName(s), _status == s, () => setState(() => _status = _status == s ? null : s)),
        ]),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Text('Showing ${shown.length} of ${dir.accounts.length}', style: AQTypography.of(context, AQText.titleSmall)),
          ),
        ),
        if (shown.isEmpty)
          AdminNotice(title: tr('No accounts match'), body: tr('Change the search or the filters.'))
        else
          AdminTable(
            headers: const ['Name', 'Role', 'Status', 'City', 'Joined'],
            flex: const [4, 3, 2, 2, 2],
            rows: [
              for (final a in shown)
                AdminTableRow(
                  key: a.id,
                  semantics: tr('${a.name}, ${roleName(a.role)}, ${acctStatusName(a.status)}'),
                  onTap: () => context.go('/accounts/${a.id}'),
                  cells: [
                    Builder(builder: (context) {
                      final c = AQColors.of(context);
                      return Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 32, height: 32, decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle, border: Border.all(color: c.hairline)), child: Center(child: AQIcon('user', size: 16, color: c.accentDeep))),
                        const SizedBox(width: 10),
                        Flexible(child: Text(a.name, style: AQTypography.of(context, AQText.titleSmall))),
                      ]);
                    }),
                    Text(roleName(a.role)),
                    Align(alignment: AlignmentDirectional.centerStart, child: adminStatusPill(acctStatusName(a.status), _acctLook(a.status))),
                    Text(a.city),
                    Text(VFmt.shortDate(context, a.joined)),
                  ],
                ),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }
}

class AdminAccountDetailScreen extends ConsumerWidget {
  final String id;
  const AdminAccountDetailScreen({super.key, required this.id});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dir = ref.watch(adminDirectoryProvider);
    final a = ref.read(adminDirectoryProvider.notifier).account(id);
    final can = _canDecide(ref);
    if (a == null) {
      return AdminFrame(section: '/accounts', title: tr('Account'), onBack: () => context.go('/accounts'), backLabel: tr('Back to accounts'), children: [AdminNotice(title: tr('We could not find this account.'))]);
    }
    final history = dir.audit.where((e) => e.target == a.name).toList();
    Future<void> change(AcctStatus s, String verb, String body) async {
      final ok = await adminConfirm(context, title: tr('$verb ${a.name}?'), body: body, action: verb);
      if (ok) ref.read(adminDirectoryProvider.notifier).setAccountStatus(a.id, s, _actor(ref));
    }

    return AdminFrame(
      section: '/accounts',
      title: a.name,
      subtitle: tr('${roleName(a.role)} · ${a.city}'),
      onBack: () => context.go('/accounts'),
      backLabel: tr('Back to accounts'),
      actions: [adminStatusPill(acctStatusName(a.status), _acctLook(a.status))],
      children: [
        AdminKeyValues([
          ('Role', roleName(a.role)),
          ('Status', acctStatusName(a.status)),
          ('Contact', a.email),
          ('City', a.city),
          ('Joined', VFmt.fullDate(context, a.joined)),
          ('Listings or projects', '${a.listings}'),
          if (a.note.isNotEmpty) ('Note', a.note),
        ]),
        adminSection(context, 'Review status'),
        if (a.role != AcctRole.shopper)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: AQNoticeLineAdmin(a.status == AcctStatus.underReview
                ? 'This business is in the verification queue. Documents are reviewed there.'
                : 'Illustrative review state only. Nothing here verifies a real business.'),
          ),
        if (!can)
          AdminNotice(icon: 'lock', title: tr('Read-only'), body: tr('Your role can view accounts but not change them.'))
        else
          Wrap(
            spacing: AQSpacing.x3,
            runSpacing: AQSpacing.x3,
            children: [
              if (a.status != AcctStatus.active)
                AdminPrimaryButton(label: tr('Set active'), trailingChevron: false, onPressed: () => change(AcctStatus.active, 'Set active', 'The account would be treated as active in this demo.')),
              if (a.status != AcctStatus.underReview)
                AdminSecondaryButton(label: tr('Mark under review'), trailingChevron: false, onPressed: () => change(AcctStatus.underReview, 'Mark under review', 'The account moves back to review in this demo.')),
              if (a.status != AcctStatus.suspended)
                AdminSecondaryButton(label: tr('Suspend'), trailingChevron: false, onPressed: () => change(AcctStatus.suspended, 'Suspend', 'Suspending is simulated: no real account is affected.')),
            ],
          ),
        adminSection(context, 'Activity on this account'),
        if (history.isEmpty)
          AdminNotice(title: tr('No administrative activity yet.'))
        else
          AdminTable(
            headers: const ['When', 'Who', 'Action'],
            flex: const [3, 3, 4],
            rows: [
              for (final (i, e) in history.indexed)
                AdminTableRow(key: 'h$i', semantics: tr('${e.actor}, ${e.text}'), cells: [Text(_date(context, e.at)), Text(e.actor), Text(e.text)]),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }
}

class AQNoticeLineAdmin extends StatelessWidget {
  final String text;
  const AQNoticeLineAdmin(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text, style: AQTypography.of(context, AQText.bodyMedium, soft: true));
}

// ------------------------------------------------------------------ reports

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});
  @override
  ConsumerState<AdminReportsScreen> createState() => _ReportsState();
}

class _ReportsState extends ConsumerState<AdminReportsScreen> {
  final _q = TextEditingController();
  ReportStatus? _status;
  ReportKind? _kind;
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dir = ref.watch(adminDirectoryProvider);
    final shown = filterReports(dir.reports, query: _q.text, status: _status, kind: _kind);
    return AdminFrame(
      section: '/reports',
      title: tr('Reports and complaints'),
      subtitle: tr('Illustrative reports from shoppers and businesses.'),
      children: [
        AdminSearchField(controller: _q, hint: tr('Search subject or summary'), onChanged: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x3),
        adminFilterRow(context, 'Status', [
          ('All', _status == null, () => setState(() => _status = null)),
          for (final s in ReportStatus.values) (reportStatusName(s), _status == s, () => setState(() => _status = _status == s ? null : s)),
        ]),
        adminFilterRow(context, 'About', [
          ('All', _kind == null, () => setState(() => _kind = null)),
          for (final k in ReportKind.values) (reportKindName(k), _kind == k, () => setState(() => _kind = _kind == k ? null : k)),
        ]),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Text('Showing ${shown.length} of ${dir.reports.length}', style: AQTypography.of(context, AQText.titleSmall)),
          ),
        ),
        if (shown.isEmpty)
          AdminNotice(title: tr('No reports match'), body: tr('Change the search or the filters.'))
        else
          AdminTable(
            headers: const ['Subject', 'About', 'Status', 'Opened'],
            flex: const [5, 2, 2, 2],
            rows: [
              for (final r in shown)
                AdminTableRow(
                  key: r.id,
                  semantics: tr('${r.subject}, ${reportKindName(r.kind)}, ${reportStatusName(r.status)}'),
                  onTap: () => context.go('/reports/${r.id}'),
                  cells: [
                    AdminThumbCell(
                      thumb: const AdminThumb(icon: 'flag', size: 40),
                      child: Text(r.subject, style: AQTypography.of(context, AQText.titleSmall)),
                    ),
                    Text(reportKindName(r.kind)),
                    Align(alignment: AlignmentDirectional.centerStart, child: adminStatusPill(reportStatusName(r.status), _reportLook(r.status))),
                    Text(VFmt.shortDate(context, r.createdAt)),
                  ],
                ),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }
}

class AdminReportDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const AdminReportDetailScreen({super.key, required this.id});
  @override
  ConsumerState<AdminReportDetailScreen> createState() => _ReportDetailState();
}

class _ReportDetailState extends ConsumerState<AdminReportDetailScreen> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _set(AdminReport r, ReportStatus s) async {
    final closing = s == ReportStatus.resolved || s == ReportStatus.dismissed;
    final ok = await adminConfirm(
      context,
      title: '${closing ? (s == ReportStatus.resolved ? 'Resolve' : 'Dismiss') : 'Move to ${reportStatusName(s).toLowerCase()}'} this report?',
      body: tr('This is simulated. Nothing is sent to the person who reported it.'),
      action: reportStatusName(s),
    );
    if (!ok) return;
    ref.read(adminDirectoryProvider.notifier).setReportStatus(r.id, s, _actor(ref), note: _note.text);
    _note.clear();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminDirectoryProvider);
    final r = ref.read(adminDirectoryProvider.notifier).report(widget.id);
    final can = _canDecide(ref);
    if (r == null) {
      return AdminFrame(section: '/reports', title: tr('Report'), onBack: () => context.go('/reports'), backLabel: tr('Back to reports'), children: [AdminNotice(title: tr('We could not find this report.'))]);
    }
    return AdminFrame(
      section: '/reports',
      title: r.subject,
      subtitle: tr('${reportKindName(r.kind)} · reported by ${r.reporter}'),
      onBack: () => context.go('/reports'),
      backLabel: tr('Back to reports'),
      actions: [adminStatusPill(reportStatusName(r.status), _reportLook(r.status))],
      children: [
        AdminKeyValues([('Opened', _date(context, r.createdAt)), ('Reported by', r.reporter), ('Summary', r.summary)]),
        adminSection(context, 'Resolution'),
        if (!can)
          AdminNotice(icon: 'lock', title: tr('Read-only'), body: tr('Your role can read reports but not change them.'))
        else ...[
          AdminField(label: tr('Resolution note (optional)'), controller: _note, minLines: 2, maxLines: 4, action: TextInputAction.newline),
          const SizedBox(height: AQSpacing.x3),
          Wrap(
            spacing: AQSpacing.x3,
            runSpacing: AQSpacing.x3,
            children: [
              if (r.status == ReportStatus.open) AdminSecondaryButton(label: tr('Start review'), trailingChevron: false, onPressed: () => _set(r, ReportStatus.inReview)),
              if (r.status != ReportStatus.resolved) AdminPrimaryButton(label: tr('Resolve'), trailingChevron: false, onPressed: () => _set(r, ReportStatus.resolved)),
              if (r.status != ReportStatus.dismissed) AdminSecondaryButton(label: tr('Dismiss'), trailingChevron: false, onPressed: () => _set(r, ReportStatus.dismissed)),
              if (r.status == ReportStatus.resolved || r.status == ReportStatus.dismissed) AdminSecondaryButton(label: tr('Reopen'), trailingChevron: false, onPressed: () => _set(r, ReportStatus.open)),
            ],
          ),
        ],
        adminSection(context, 'Notes'),
        if (r.notes.isEmpty)
          AdminNotice(title: tr('No notes yet.'))
        else
          AdminTable(
            headers: const ['When', 'By', 'Note'],
            flex: const [3, 3, 6],
            rows: [
              for (final (i, n) in r.notes.indexed)
                AdminTableRow(key: 'n$i', semantics: tr('${n.by}: ${n.text}'), cells: [Text(_date(context, n.at)), Text(n.by), Text(n.text)]),
            ],
          ),
        adminDemoNotice(),
      ],
    );
  }
}

// ------------------------------------------------------------------ audit log

class AdminAuditScreen extends ConsumerWidget {
  const AdminAuditScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dir = ref.watch(adminDirectoryProvider);
    return AdminFrame(
      section: '/audit',
      title: tr('Activity log'),
      subtitle: tr('Fictional demo events. Changes you make in this session appear at the top; none of them touch a real record.'),
      children: [
        AdminTable(
          headers: const ['When', 'Who', 'Action', 'Record'],
          flex: const [3, 3, 4, 4],
          rows: [
            for (final (i, e) in dir.audit.indexed)
              AdminTableRow(key: 'a$i', semantics: '${e.actor}, ${e.text}, ${e.target ?? ''}', cells: [Text(_date(context, e.at)), Text(e.actor), Text(e.text), Text(e.target ?? '')]),
          ],
        ),
        adminDemoNotice(),
      ],
    );
  }
}
