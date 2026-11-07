import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/auth/auth_repository.dart';
import '../../data/api/account_api.dart' show meProvider, verificationProvider;
import '../leads/phone_launcher.dart';
import '../role_home/role_home_model.dart'
    show HomeWorkspace;
import '../search/aq_filter_sheet.dart' show AQChoicePill;
import '../search/aq_search.dart' show AQQueryField;
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart' show AQShellInset;
import '../contact/contact_actions.dart';
import 'agent_crm.dart';
import '../ads/ad_models.dart' show AdAudience;
import '../role_home/role_home_model.dart' show HomeRole;
import '../analytics/analytics_charts.dart' show KpiGrid, KpiTile;
import '../role_home/mode_switch.dart' show switchToShop, switchToWork;
import '../role_home/role_home_widgets.dart' show RoleWorkspaceSwitcher;
import '../ads/sponsored_banner.dart';
import '../analytics/analytics_screens.dart' show RoleKpiStrip;

// ---------------------------------------------------------------- shared pieces

/// One agent page: a title row, optional trailing action and a scrolling body that leaves room for
/// the agent navigation. Deliberately not the customer page frame.
class _AgentPage extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final Widget? action;
  final bool back;
  final List<Widget> children;
  const _AgentPage({
    required this.title,
    required this.children,
    this.eyebrow,
    this.action,
    this.back = false,
  });
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final stackAction = aqLargeText(context) || MediaQuery.sizeOf(context).width < 400;
    return SafeArea(
      bottom: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              AQSpacing.gutter,
              AQSpacing.x4,
              AQSpacing.gutter,
              AQSpacing.x6 + AQShellInset.of(context) + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (back)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: AQSpacing.x2),
                        child: AQIconButton(
                          icon: 'chevron-left',
                          semanticsLabel: f.t('common.back'),
                          onPressed: () => aqBack(context, '/agent'),
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (eyebrow != null)
                            Text(
                              eyebrow!,
                              style: AQTypography.of(
                                context,
                                AQText.labelSmall,
                                color: c.accentDeep,
                              ),
                            ),
                          Semantics(
                            header: true,
                            child: Text(
                              title,
                              style: AQTypography.of(context, AQText.headlineLarge),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!stackAction) ?action,
                  ],
                ),
                // On a narrow phone or at large text the action sits under the title, full width of
                // its own line, instead of squeezing the title into a column.
                if (stackAction && action != null) ...[const SizedBox(height: AQSpacing.x3), Align(alignment: AlignmentDirectional.centerStart, child: action!)],
                const SizedBox(height: AQSpacing.x4),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return (p.first.isEmpty ? '?' : p.first[0]) + (p.length > 1 ? p[1][0] : '');
}

AQTone _toneFor(LeadStatus s) => switch (s) {
  LeadStatus.fresh => AQTone.pending,
  LeadStatus.contacted => AQTone.neutral,
  LeadStatus.viewing => AQTone.warning,
  LeadStatus.negotiating => AQTone.warning,
  LeadStatus.won => AQTone.success,
  LeadStatus.lost => AQTone.danger,
};

class _StatusPill extends StatelessWidget {
  final LeadStatus status;
  const _StatusPill(this.status);
  @override
  Widget build(BuildContext context) => AQStatusPill(
    label: FlowStrings.of(context).t('ag.st.${status.name}'),
    tone: _toneFor(status),
    dense: true,
  );
}

class _Section extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final List<Widget> children;
  const _Section({
    required this.title,
    required this.children,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AQSpacing.x5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x2),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AQTypography.of(context, AQText.titleMedium),
                  ),
                ),
              ),
              if (action != null)
                AQTextButton(
                  label: action!,
                  color: AQColors.of(context).accent,
                  onPressed: onAction,
                ),
            ],
          ),
        ),
        ...children,
      ],
    ),
  );
}

class _Note extends StatelessWidget {
  final String text;
  const _Note(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
    child: Text(
      text,
      style: AQTypography.of(context, AQText.bodySmall, soft: true),
    ),
  );
}

/// A tappable list row (contact, appointment, quick action).
class _Tap extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;
  const _Tap({required this.label, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    focusable: true,
    onFocus: () {},
    label: label,
    excludeSemantics: true,
    onTap: onTap,
    child: AQPressable(onTap: onTap, child: child),
  );
}

String _when(BuildContext context, DateTime d) {
  final f = FlowStrings.of(context);
  final now = DateTime.now();
  final a = DateTime(now.year, now.month, now.day);
  final b = DateTime(d.year, d.month, d.day);
  final diff = b.difference(a).inDays;
  final day = diff == 0
      ? f.t('ag.when.today')
      : diff == 1
          ? f.t('ag.when.tomorrow')
          : VFmt.shortDate(context, d);
  return '$day, ${VFmt.time(context, d)}';
}

Future<DateTime?> _pickDateTime(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final day = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(now) ? now : initial,
    firstDate: DateTime(now.year, now.month, now.day),
    lastDate: DateTime(now.year + 1, now.month, now.day),
  );
  if (day == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  if (time == null) return null;
  return DateTime(day.year, day.month, day.day, time.hour, time.minute);
}

// ---------------------------------------------------------------- dashboard

/// What needs the agent today: counts from the demo records, what is coming up, what is overdue,
/// and the latest notes. Every number is computed from the records below, never invented.
class AgentDashboardScreen extends ConsumerWidget {
  const AgentDashboardScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final crm = ref.watch(agentCrmProvider);
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59);
    final open = crm.contacts
        .where((c) => c.status != LeadStatus.won && c.status != LeadStatus.lost)
        .toList();
    final fresh = crm.contacts.where((c) => c.status == LeadStatus.fresh).length;
    final ahead = crm.appointments
        .where((a) => a.status == AppointmentStatus.scheduled && a.kind == AppointmentKind.viewing && !a.at.isBefore(now))
        .length;
    final due = open
        .where((c) => c.nextFollowUp != null && !c.nextFollowUp!.isAfter(endOfToday))
        .toList()
      ..sort((a, b) => a.nextFollowUp!.compareTo(b.nextFollowUp!));
    final upcoming = crm.appointments
        .where((a) => a.status == AppointmentStatus.scheduled && !a.at.isBefore(DateTime(now.year, now.month, now.day)))
        .toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final recent = [
      for (final c in crm.contacts)
        for (final n in c.notes) (c, n),
    ]..sort((a, b) => b.$2.at.compareTo(a.$2.at));
    KpiTile kpi(String key, int n, String path, String icon) => KpiTile(label: f.t(key), value: '$n', icon: icon, onTap: () => context.go(path));
    return _AgentPage(
      eyebrow: f.t('ag.dash.eyebrow'),
      title: f.t('ag.dash.title'),
      children: [
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: RoleWorkspaceSwitcher(
            selected: HomeWorkspace.agent,
            // Shop is the same account in its customer view: the choice is kept, nothing is reset.
            onChanged: (w) => w == HomeWorkspace.buyer ? switchToShop(context, ref) : switchToWork(context, ref),
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        DbDemoLine(f.t('ag.demo')),
        const SizedBox(height: AQSpacing.x4),
        Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x5),
          child: KpiGrid(tiles: [
            kpi('ag.k.leads', fresh, '/agent/contacts', 'account'),
            kpi('ag.k.open', open.length, '/agent/contacts', 'activity'),
            kpi('ag.k.viewings', ahead, '/agent/calendar', 'calendar'),
            kpi('ag.k.follow', due.length, '/agent/contacts', 'clock'),
          ]),
        ),
        const SponsoredBannerSlot(audience: AdAudience.agent),
        const RoleKpiStrip(role: HomeRole.agent, linkOnly: true),
        const SizedBox(height: AQSpacing.x5),
        _Section(
          title: f.t('ag.dash.today'),
          action: f.t('ag.all'),
          onAction: () => context.go('/agent/calendar'),
          children: [
            if (upcoming.isEmpty) _Note(f.t('ag.dash.todayEmpty')),
            for (final a in upcoming.take(4)) _AppointmentRow(a),
          ],
        ),
        _Section(
          title: f.t('ag.dash.due'),
          children: [
            if (due.isEmpty) _Note(f.t('ag.dash.dueEmpty')),
            for (final c in due.take(4)) _ContactRow(c),
          ],
        ),
        _Section(
          title: f.t('ag.dash.recent'),
          children: [
            for (final r in recent.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x2),
                child: _Tap(
                  label: '${r.$1.name}: ${r.$2.text}',
                  onTap: () => context.push('/agent/contacts/${r.$1.id}'),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: AQSpacing.x3),
                        child: AQIcon('clock', size: 16, color: AQColors.of(context).inkSoft),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.$1.name,
                              style: AQTypography.of(context, AQText.titleSmall),
                            ),
                            Text(
                              r.$2.text,
                              style: AQTypography.of(context, AQText.bodySmall, soft: true),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        _Section(
          title: f.t('ag.dash.quick'),
          children: [
            AQSecondaryButton(
              label: f.t('ag.q.addContact'),
              leadingIcon: 'plus',
              trailingChevron: false,
              onPressed: () => context.push('/agent/contacts/new'),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ag.q.addListing'),
              leadingIcon: 'development',
              trailingChevron: false,
              onPressed: () => context.push('/agent/listings/new'),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ag.q.requests'),
              leadingIcon: 'calendar-check',
              trailingChevron: false,
              onPressed: () => context.push('/agent/leads'),
            ),
          ],
        ),
      ],
    );
  }
}

/// A one-line demo disclosure.
class DbDemoLine extends StatelessWidget {
  final String text;
  const DbDemoLine(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 2),
        child: AQIcon('info', size: 16, color: AQColors.of(context).inkFaint),
      ),
      const SizedBox(width: AQSpacing.x2),
      Expanded(
        child: Text(
          text,
          style: AQTypography.of(
            context,
            AQText.bodySmall,
            color: AQColors.of(context).inkFaint,
          ),
        ),
      ),
    ],
  );
}

// ---------------------------------------------------------------- contacts

enum ContactSort { recent, name, follow }

/// The filter and sort behind the contact list (pure, so it can be unit tested).
List<AgentContact> filterContacts(
  List<AgentContact> all, {
  String query = '',
  LeadStatus? status,
  ContactSort sort = ContactSort.recent,
}) {
  final q = query.trim().toLowerCase();
  final out = [
    for (final c in all)
      if ((status == null || c.status == status) &&
          (q.isEmpty ||
              '${c.name} ${c.location} ${c.interests.join(' ')} ${c.source}'
                  .toLowerCase()
                  .contains(q)))
        c,
  ];
  switch (sort) {
    case ContactSort.recent:
      out.sort((a, b) => b.lastInteraction.compareTo(a.lastInteraction));
    case ContactSort.name:
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    case ContactSort.follow:
      out.sort((a, b) {
        if (a.nextFollowUp == null && b.nextFollowUp == null) return 0;
        if (a.nextFollowUp == null) return 1;
        if (b.nextFollowUp == null) return -1;
        return a.nextFollowUp!.compareTo(b.nextFollowUp!);
      });
  }
  return out;
}

class _ContactRow extends StatelessWidget {
  final AgentContact contact;
  const _ContactRow(this.contact);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final k = contact;
    final overdue = k.followUpOverdue(DateTime.now());
    final follow = k.nextFollowUp == null
        ? f.t('ag.noFollow')
        : (overdue
              ? f.t('ag.overdue')
              : f.t('ag.followOn', {'d': _when(context, k.nextFollowUp!)}));
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x2),
      child: _Tap(
        label: '${k.name}, ${f.t('ag.st.${k.status.name}')}, $follow',
        onTap: () => context.push('/agent/contacts/${k.id}'),
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle, border: Border.all(color: c.hairline)),
                child: Center(
                  child: Text(
                    _initials(k.name).toUpperCase(),
                    style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep),
                  ),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(k.name, style: AQTypography.of(context, AQText.titleMedium)),
                    Text(
                      [...k.interests, if (k.location.isNotEmpty) k.location].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AQTypography.of(context, AQText.bodySmall, soft: true),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      follow,
                      style: AQTypography.of(
                        context,
                        AQText.labelMedium,
                        color: overdue ? c.danger : c.inkSoft,
                      ),
                    ),
                    // At large text the status goes under the text instead of squeezing the row.
                    if (aqLargeText(context)) ...[
                      const SizedBox(height: AQSpacing.x1),
                      _StatusPill(k.status),
                    ],
                  ],
                ),
              ),
              if (!aqLargeText(context)) ...[
                const SizedBox(width: AQSpacing.x2),
                _StatusPill(k.status),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AgentContactsScreen extends ConsumerStatefulWidget {
  const AgentContactsScreen({super.key});
  @override
  ConsumerState<AgentContactsScreen> createState() => _ContactsState();
}

class _ContactsState extends ConsumerState<AgentContactsScreen> {
  final _ctl = TextEditingController();
  LeadStatus? _status;
  ContactSort _sort = ContactSort.recent;
  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final crm = ref.watch(agentCrmProvider);
    final shown = filterContacts(crm.contacts, query: _ctl.text, status: _status, sort: _sort);
    final filtered = _status != null || _ctl.text.trim().isNotEmpty;
    return _AgentPage(
      title: f.t('ag.c.title'),
      action: AQSecondaryButton(
        label: f.t('ag.c.add'),
        leadingIcon: 'plus',
        trailingChevron: false,
        compact: true,
        onPressed: () => context.push('/agent/contacts/new'),
      ),
      children: [
        AQQueryField(
          controller: _ctl,
          hint: f.t('ag.c.search'),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => setState(() {}),
        ),
        const SizedBox(height: AQSpacing.x3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AQChoicePill(label: f.t('ag.f.all'), selected: _status == null, onTap: () => setState(() => _status = null)),
              for (final s in LeadStatus.values) ...[
                const SizedBox(width: AQSpacing.x2),
                AQChoicePill(
                  label: f.t('ag.st.${s.name}'),
                  selected: _status == s,
                  onTap: () => setState(() => _status = _status == s ? null : s),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final s in ContactSort.values) ...[
                if (s != ContactSort.values.first) const SizedBox(width: AQSpacing.x2),
                AQChoicePill(
                  label: f.t('ag.sort.${s.name}'),
                  selected: _sort == s,
                  onTap: () => setState(() => _sort = s),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x4),
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Text(
              f.t('ag.c.count', {'n': '${shown.length}'}),
              style: AQTypography.of(context, AQText.titleSmall),
            ),
          ),
        ),
        if (shown.isEmpty)
          AQEmptyViewingState(
            title: f.t('ag.c.empty.t'),
            body: f.t('ag.c.empty.b'),
            action: filtered
                ? AQSecondaryButton(
                    label: f.t('ag.c.clear'),
                    trailingChevron: false,
                    onPressed: () => setState(() {
                      _ctl.clear();
                      _status = null;
                    }),
                  )
                : null,
          )
        else
          for (final k in shown) _ContactRow(k),
      ],
    );
  }
}

// ---------------------------------------------------------------- contact detail

class AgentContactScreen extends ConsumerStatefulWidget {
  final String id;
  const AgentContactScreen({super.key, required this.id});
  @override
  ConsumerState<AgentContactScreen> createState() => _ContactState();
}

class _ContactState extends ConsumerState<AgentContactScreen> {
  final _note = TextEditingController();
  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _call(AgentContact k) async {
    final opened = await ref.read(phoneLauncherProvider).dial(k.phone);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(FlowStrings.of(context).t(opened ? 'ag.d.demoCall' : 'ag.d.demoCall'))),
    );
  }

  Future<void> _mail(AgentContact k) async {
    if (k.email.isEmpty) return;
    try {
      await launchUrl(Uri(scheme: 'mailto', path: k.email));
    } catch (_) {}
  }

  Future<void> _schedule(AgentContact k) async {
    final at = await _pickDateTime(
      context,
      k.nextFollowUp ?? DateTime.now().add(const Duration(days: 1)),
    );
    if (at != null) ref.read(agentCrmProvider.notifier).scheduleFollowUp(k.id, at);
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final crm = ref.watch(agentCrmProvider);
    AgentContact? k;
    for (final x in crm.contacts) {
      if (x.id == widget.id) k = x;
    }
    if (k == null) {
      return _AgentPage(
        back: true,
        title: f.t('ag.d.title'),
        children: [_Note(f.t('ag.d.notFound'))],
      );
    }
    final contact = k;
    final appts = crm.appointments.where((a) => a.contactId == contact.id).toList()
      ..sort((a, b) => b.at.compareTo(a.at));
    String budget() {
      if (contact.budgetMin == null && contact.budgetMax == null) return '-';
      return 'OMR ${contact.budgetMin ?? '…'} - ${contact.budgetMax ?? '…'}';
    }

    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          ),
          Expanded(child: Text(value, style: AQTypography.of(context, AQText.bodyMedium))),
        ],
      ),
    );
    return _AgentPage(
      back: true,
      title: contact.name,
      eyebrow: f.t('ag.d.title').toUpperCase(),
      action: _StatusPill(contact.status),
      children: [
        AQContactButtons(name: contact.name, phone: contact.phone),
        const SizedBox(height: AQSpacing.x3),
        Row(
          children: [
            Expanded(
              child: AQPrimaryButton(
                label: f.t('ag.d.call'),
                leadingIcon: 'phone',
                trailingChevron: false,
                onPressed: () => _call(contact),
              ),
            ),
            const SizedBox(width: AQSpacing.x2),
            Expanded(
              child: AQSecondaryButton(
                label: f.t('ag.d.edit'),
                leadingIcon: 'edit',
                trailingChevron: false,
                onPressed: () => context.push('/agent/contacts/${contact.id}/edit'),
              ),
            ),
          ],
        ),
        if (contact.email.isNotEmpty) ...[
          const SizedBox(height: AQSpacing.x1),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AQTextButton(
              label: '${f.t('ag.d.email')}: ${contact.email}',
              color: c.accent,
              onPressed: () => _mail(contact),
            ),
          ),
        ],
        const SizedBox(height: AQSpacing.x4),
        AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Column(
            children: [
              row(f.t('ag.d.source'), contact.source),
              row(f.t('ag.d.interests'), contact.interests.isEmpty ? '-' : contact.interests.join(', ')),
              row(f.t('ag.d.location'), contact.location.isEmpty ? '-' : contact.location),
              row(f.t('ag.d.budget'), budget()),
              row(f.t('ag.d.follow'), contact.nextFollowUp == null ? f.t('ag.noFollow') : _when(context, contact.nextFollowUp!)),
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQSecondaryButton(
          label: f.t('ag.d.schedule'),
          leadingIcon: 'calendar',
          trailingChevron: false,
          onPressed: () => _schedule(contact),
        ),
        const SizedBox(height: AQSpacing.x5),
        _Section(
          title: f.t('ag.d.status'),
          children: [
            Wrap(
              spacing: AQSpacing.x2,
              runSpacing: AQSpacing.x2,
              children: [
                for (final s in LeadStatus.values)
                  AQChoicePill(
                    label: f.t('ag.st.${s.name}'),
                    selected: contact.status == s,
                    onTap: () => ref.read(agentCrmProvider.notifier).setStatus(contact.id, s),
                  ),
              ],
            ),
          ],
        ),
        if (contact.listingIds.isNotEmpty)
          _Section(
            title: f.t('ag.d.listings'),
            children: [
              for (final id in contact.listingIds)
                _Tap(
                  label: kDemoListingTitles[id] ?? id,
                  onTap: () => context.go('/agent/listings'),
                  child: AQSurface(
                    padding: const EdgeInsets.all(AQSpacing.x3),
                    child: Row(
                      children: [
                        AQIcon('development', size: 18, color: c.accent),
                        const SizedBox(width: AQSpacing.x3),
                        Expanded(child: Text(kDemoListingTitles[id] ?? id, style: AQTypography.of(context, AQText.bodyMedium))),
                        const AQIcon('chevron-right', size: 16, directional: true),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        _Section(
          title: f.t('ag.d.appts'),
          children: [
            if (appts.isEmpty) _Note(f.t('ag.d.noAppts')),
            for (final a in appts) _AppointmentRow(a),
          ],
        ),
        _Section(
          title: f.t('ag.d.notes'),
          children: [
            AQTextField(
              label: f.t('ag.d.notePh'),
              controller: _note,
              minLines: 2,
              maxLines: 4,
              action: TextInputAction.newline,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AQSpacing.x2),
            AQSecondaryButton(
              label: f.t('ag.d.noteSave'),
              trailingChevron: false,
              onPressed: _note.text.trim().isEmpty
                  ? null
                  : () {
                      ref.read(agentCrmProvider.notifier).addNote(contact.id, _note.text);
                      _note.clear();
                      setState(() {});
                    },
            ),
            const SizedBox(height: AQSpacing.x3),
            if (contact.notes.isEmpty) _Note(f.t('ag.d.noNotes')),
            for (final n in contact.notes)
              Padding(
                padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 4, right: AQSpacing.x3),
                      child: AQIcon(
                        switch (n.kind) {
                          NoteKind.call => 'phone',
                          NoteKind.viewing => 'calendar',
                          NoteKind.status => 'check',
                          _ => 'edit',
                        },
                        size: 16,
                        color: c.accent,
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(n.text, style: AQTypography.of(context, AQText.bodyMedium)),
                          Text(
                            '${VFmt.shortDate(context, n.at)}, ${VFmt.time(context, n.at)}',
                            style: AQTypography.of(context, AQText.bodySmall, soft: true),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- contact form

class AgentContactFormScreen extends ConsumerStatefulWidget {
  final String? editId;
  const AgentContactFormScreen({super.key, this.editId});
  @override
  ConsumerState<AgentContactFormScreen> createState() => _FormState();
}

class _FormState extends ConsumerState<AgentContactFormScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _mail = TextEditingController();
  final _loc = TextEditingController();
  final _int = TextEditingController();
  final _min = TextEditingController();
  final _max = TextEditingController();
  bool _tried = false, _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _mail, _loc, _int, _min, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load() {
    if (_loaded) return;
    _loaded = true;
    final id = widget.editId;
    if (id == null) return;
    final k = ref.read(agentCrmProvider.notifier).contact(id);
    if (k == null) return;
    _name.text = k.name;
    _phone.text = k.phone;
    _mail.text = k.email;
    _loc.text = k.location;
    _int.text = k.interests.join(', ');
    _min.text = k.budgetMin?.toString() ?? '';
    _max.text = k.budgetMax?.toString() ?? '';
  }

  String? get _errName => _name.text.trim().isEmpty ? 'ag.f.errName' : null;
  String? get _errPhone => _phone.text.trim().isEmpty ? 'ag.f.errPhone' : null;
  String? get _errBudget {
    final lo = int.tryParse(_min.text.trim()), hi = int.tryParse(_max.text.trim());
    return lo != null && hi != null && hi < lo ? 'ag.f.errBudget' : null;
  }

  void _save() {
    setState(() => _tried = true);
    if (_errName != null || _errPhone != null || _errBudget != null) return;
    final interests = [
      for (final s in _int.text.split(',')) if (s.trim().isNotEmpty) s.trim(),
    ];
    final lo = int.tryParse(_min.text.trim()), hi = int.tryParse(_max.text.trim());
    final crm = ref.read(agentCrmProvider.notifier);
    var id = widget.editId;
    if (id == null) {
      id = crm.addContact(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _mail.text.trim(),
        interests: interests,
        location: _loc.text.trim(),
        budgetMin: lo,
        budgetMax: hi,
      );
    } else {
      crm.edit(id, (c) => c.copyWith(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _mail.text.trim(),
        interests: interests,
        location: _loc.text.trim(),
        budgetMin: lo,
        budgetMax: hi,
      ));
    }
    context.pushReplacement('/agent/contacts/$id');
  }

  @override
  Widget build(BuildContext context) {
    _load();
    final f = FlowStrings.of(context);
    String? err(String? k) => _tried && k != null ? f.t(k) : null;
    return _AgentPage(
      back: true,
      title: f.t(widget.editId == null ? 'ag.f.new' : 'ag.f.edit'),
      children: [
        AQTextField(label: f.t('ag.f.name'), controller: _name, error: err(_errName), onChanged: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x3),
        AQTextField(label: f.t('ag.f.phone'), controller: _phone, keyboardType: TextInputType.phone, error: err(_errPhone), onChanged: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x3),
        AQTextField(label: f.t('ag.f.mail'), controller: _mail, keyboardType: TextInputType.emailAddress),
        const SizedBox(height: AQSpacing.x3),
        AQTextField(label: f.t('ag.f.loc'), controller: _loc),
        const SizedBox(height: AQSpacing.x3),
        AQTextField(label: f.t('ag.f.int'), controller: _int),
        const SizedBox(height: AQSpacing.x3),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: AQTextField(label: f.t('ag.f.min'), controller: _min, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], onChanged: (_) => setState(() {}))),
            const SizedBox(width: AQSpacing.x3),
            Expanded(child: AQTextField(label: f.t('ag.f.max'), controller: _max, keyboardType: TextInputType.number, formatters: [FilteringTextInputFormatter.digitsOnly], error: err(_errBudget), onChanged: (_) => setState(() {}))),
          ],
        ),
        const SizedBox(height: AQSpacing.x5),
        AQPrimaryButton(label: f.t('ag.f.save'), trailingChevron: false, onPressed: _save),
      ],
    );
  }
}

// ---------------------------------------------------------------- calendar

class _AppointmentRow extends ConsumerWidget {
  final Appointment appt;
  const _AppointmentRow(this.appt);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final a = appt;
    final st = a.status;
    final overdue = st == AppointmentStatus.scheduled && a.at.isBefore(DateTime.now());
    final pill = st != AppointmentStatus.scheduled
        ? AQStatusPill(
            label: f.t('ag.cal.st.${st == AppointmentStatus.done ? 'done' : 'cancelled'}'),
            tone: st == AppointmentStatus.done ? AQTone.success : AQTone.neutral,
            dense: true,
          )
        : AQStatusPill(label: f.t('ag.cal.kind.${a.kind.name}'), tone: AQTone.pending, dense: true);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x2),
      child: _Tap(
        label: '${a.title}, ${_when(context, a.at)}',
        onTap: () => showAppointmentSheet(context, ref, a.id),
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Row(
            children: [
              // Date first: the day and month read at a glance, with the kind of appointment underneath.
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
                decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(AQRadius.small + 4), border: Border.all(color: overdue ? c.danger : c.hairline)),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(VFmt.dayNum(context, a.at), style: AQTypography.of(context, AQText.headlineSmall, color: overdue ? c.danger : c.accentDeep)),
                  Text(VFmt.weekdayShort(context, a.at), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  const SizedBox(height: 2),
                  AQIcon(a.kind == AppointmentKind.viewing ? 'eye' : (a.kind == AppointmentKind.meeting ? 'account' : 'phone'), size: 14, color: c.accent),
                ]),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.title, style: AQTypography.of(context, AQText.titleMedium)),
                    Text(
                      _when(context, a.at),
                      style: AQTypography.of(context, AQText.bodySmall, color: overdue ? c.danger : c.inkSoft),
                    ),
                    if (a.listingTitle != null)
                      Text(a.listingTitle!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                    if (aqLargeText(context)) ...[const SizedBox(height: AQSpacing.x1), pill],
                  ],
                ),
              ),
              if (!aqLargeText(context)) pill,
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAppointmentSheet(BuildContext context, WidgetRef ref, String id) {
  return showAQSheet<void>(
    context,
    useRootNavigator: true,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final f = FlowStrings.of(context);
        final crm = ref.watch(agentCrmProvider);
        Appointment? a;
        for (final x in crm.appointments) {
          if (x.id == id) a = x;
        }
        if (a == null) return const SizedBox.shrink();
        final appt = a;
        AgentContact? who;
        for (final x in crm.contacts) {
          if (x.id == appt.contactId) who = x;
        }
        final open = appt.status == AppointmentStatus.scheduled;
        return Padding(
          padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(appt.title, style: AQTypography.of(context, AQText.headlineSmall))),
              const SizedBox(height: AQSpacing.x1),
              Text(
                '${f.t('ag.cal.kind.${appt.kind.name}')} · ${_when(context, appt.at)}',
                style: AQTypography.of(context, AQText.bodyMedium, soft: true),
              ),
              if (appt.listingTitle != null) Text(appt.listingTitle!, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
              const SizedBox(height: AQSpacing.x2),
              Text(f.t('ag.cal.simulated'), style: AQTypography.of(context, AQText.bodySmall, color: AQColors.of(context).inkFaint)),
              const SizedBox(height: AQSpacing.x4),
              if (who != null)
                AQSecondaryButton(
                  label: who.name,
                  leadingIcon: 'account',
                  trailingChevron: false,
                  onPressed: () {
                    Navigator.of(sheet).pop();
                    context.push('/agent/contacts/${who!.id}');
                  },
                ),
              if (open) ...[
                const SizedBox(height: AQSpacing.x2),
                AQPrimaryButton(
                  label: f.t('ag.cal.reschedule'),
                  trailingChevron: false,
                  onPressed: () async {
                    final at = await _pickDateTime(context, appt.at);
                    if (at != null) ref.read(agentCrmProvider.notifier).reschedule(appt.id, at);
                  },
                ),
                const SizedBox(height: AQSpacing.x2),
                AQSecondaryButton(
                  label: f.t('ag.cal.done.btn'),
                  trailingChevron: false,
                  onPressed: () {
                    ref.read(agentCrmProvider.notifier).setAppointmentStatus(appt.id, AppointmentStatus.done);
                    Navigator.of(sheet).pop();
                  },
                ),
                AQTextButton(
                  label: f.t('ag.cal.cancel'),
                  color: AQColors.of(context).danger,
                  onPressed: () {
                    ref.read(agentCrmProvider.notifier).setAppointmentStatus(appt.id, AppointmentStatus.cancelled);
                    Navigator.of(sheet).pop();
                  },
                ),
              ],
            ],
          ),
        );
      },
    ),
  );
}

class AgentCalendarScreen extends ConsumerStatefulWidget {
  const AgentCalendarScreen({super.key});
  @override
  ConsumerState<AgentCalendarScreen> createState() => _CalendarState();
}

class _CalendarState extends ConsumerState<AgentCalendarScreen> {
  int _tab = 0; // 0 upcoming, 1 overdue, 2 done and cancelled
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final crm = ref.watch(agentCrmProvider);
    final now = DateTime.now();
    final sched = crm.appointments.where((a) => a.status == AppointmentStatus.scheduled);
    final lists = [
      sched.where((a) => !a.at.isBefore(now)).toList()..sort((a, b) => a.at.compareTo(b.at)),
      sched.where((a) => a.at.isBefore(now)).toList()..sort((a, b) => a.at.compareTo(b.at)),
      crm.appointments.where((a) => a.status != AppointmentStatus.scheduled).toList()..sort((a, b) => b.at.compareTo(a.at)),
    ];
    final shown = lists[_tab];
    final days = <String, List<Appointment>>{};
    for (final a in shown) {
      days.putIfAbsent(VFmt.fullDate(context, a.at), () => []).add(a);
    }
    final keys = ['ag.cal.upcoming', 'ag.cal.overdue', 'ag.cal.done'];
    return _AgentPage(
      title: f.t('ag.cal.title'),
      children: [
        DbDemoLine(f.t('ag.demo')),
        const SizedBox(height: AQSpacing.x4),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: AQSpacing.x2),
                AQChoicePill(
                  label: '${f.t(keys[i])} (${lists[i].length})',
                  selected: _tab == i,
                  onTap: () => setState(() => _tab = i),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x4),
        if (shown.isEmpty) AQNoticeLine(f.t('ag.cal.empty')),
        for (final e in days.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x2, top: AQSpacing.x2),
            child: Semantics(header: true, child: Text(e.key, style: AQTypography.of(context, AQText.labelMedium, soft: true))),
          ),
          for (final a in e.value) _AppointmentRow(a),
        ],
      ],
    );
  }
}

/// Plain centred note used for empty lists.
class AQNoticeLine extends StatelessWidget {
  final String text;
  const AQNoticeLine(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x6),
    child: Text(text, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
  );
}

// ---------------------------------------------------------------- more

class AgentMoreScreen extends ConsumerWidget {
  const AgentMoreScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    Widget row(String icon, String title, VoidCallback onTap, {String? sub, bool danger = false}) => _Tap(
      label: sub == null ? title : '$title. $sub',
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4, vertical: AQSpacing.x2),
        child: Row(
          children: [
            AQIcon(icon, size: 20, color: danger ? c.danger : c.accent),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: AQTypography.of(context, AQText.bodyMedium, color: danger ? c.danger : c.ink)),
                  if (sub != null) Text(sub, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                ],
              ),
            ),
            AQIcon('chevron-right', size: 16, color: c.inkSoft, directional: true),
          ],
        ),
      ),
    );
    Widget group(String title, List<Widget> rows) => _Section(
      title: title,
      children: [
        Container(
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) Divider(height: 1, thickness: 1, color: c.hairline, indent: AQSpacing.x4, endIndent: AQSpacing.x4),
                rows[i],
              ],
            ],
          ),
        ),
      ],
    );
    return _AgentPage(
      title: f.t('ag.more.title'),
      children: [
        group(f.t('ag.more.work'), [
          row('activity', f.t('an.title'), () => context.push('/agent/analytics')),
          row('user', f.t('st.bz.link'), () => context.push('/agent/settings')),
          row('agent', f.t('ag.more.profile'), () => context.push('/verification/details')),
          row('calendar-check', f.t('ag.more.requests'), () => context.push('/agent/leads')),
          row('info', f.t('ag.more.enq'), () => context.push('/workspace/enquiries')),
          row('construction', f.t('ag.more.svc'), () => context.push('/workspace/requests')),
        ]),
        group(f.t('ag.more.account'), [
          row('user', f.t('pp.title'), () => context.push('/app/account/photo')),
          row('home', f.t('ag.more.customer'), () => switchToShop(context, ref), sub: f.t('ag.more.customer.s')),
          row('lock', f.t('ag.more.signOut'), () async {
            await ref.read(authRepositoryProvider).signOut();
            ref.invalidate(meProvider);
            ref.invalidate(verificationProvider);
            if (context.mounted) context.go('/entry');
          }),
        ]),
      ],
    );
  }
}
