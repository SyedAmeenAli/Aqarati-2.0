import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/config/demo_mode.dart' show kDemoMode;
import '../agent/agent_crm.dart';
import '../viewing/widgets/viewing_format.dart' show VFmt;
import '../devbuild/db_models.dart';
import '../devbuild/db_repository.dart';
import '../devbuild/db_workspace.dart' show DbShellPage;
import '../role_home/role_home_model.dart';
import 'analytics_charts.dart';

/// Deterministic sample series: the same role and key always give the same twelve weeks, so a chart
/// never changes between visits. These are invented sample events, not measurements.
List<double> sampleWeekly(String key, {double base = 8, double amp = 5, int weeks = 12}) {
  var h = 2166136261;
  for (final u in key.codeUnits) {
    h = ((h ^ u) * 16777619) & 0x7fffffff;
  }
  final out = <double>[];
  for (var i = 0; i < weeks; i++) {
    h = (h * 1103515245 + 12345) & 0x7fffffff;
    final wobble = (h % 1000) / 1000 - 0.5;
    final trend = i * (amp / weeks) * 0.9;
    out.add((base + trend + wobble * amp).clamp(1, 9999).roundToDouble());
  }
  return out;
}

String roleKey(HomeRole r) => r.name;

/// Where a role's analytics live (inside its own shell).
String analyticsRouteFor(HomeRole r) => r == HomeRole.agent ? '/agent/analytics' : '/pro/analytics';

/// The records the analytics read from this session's local demo state.
class _Snapshot {
  final List<AgentContact> contacts;
  final List<Appointment> appointments;
  final List<DbProject> projects;
  final List<ContactEvent> events;
  final List<Engagement> engagements;
  final List<PortfolioItem> portfolio;
  final bool eventsOk, engagementsOk, portfolioOk;
  const _Snapshot({
    this.contacts = const [],
    this.appointments = const [],
    this.projects = const [],
    this.events = const [],
    this.engagements = const [],
    this.portfolio = const [],
    this.eventsOk = false,
    this.engagementsOk = false,
    this.portfolioOk = false,
  });
}

_Snapshot _read(WidgetRef ref) {
  final crm = ref.watch(agentCrmProvider);
  final projects = ref.watch(dbMyProjectsProvider).valueOrNull ?? const <DbProject>[];
  final ev = ref.watch(dbMyContactEventsProvider);
  final en = ref.watch(dbMyEngagementsProvider);
  final pf = ref.watch(dbMyPortfolioProvider);
  return _Snapshot(
    contacts: crm.contacts,
    appointments: crm.appointments,
    projects: projects,
    events: ev.valueOrNull ?? const [],
    engagements: en.valueOrNull ?? const [],
    portfolio: pf.valueOrNull ?? const [],
    eventsOk: ev.hasValue,
    engagementsOk: en.hasValue,
    portfolioOk: pf.hasValue,
  );
}

/// Three small headline figures for a role's Home, from the same records as the analytics page.
List<KpiTile> roleKpis(BuildContext context, WidgetRef ref, HomeRole role) {
  final f = FlowStrings.of(context);
  final s = _read(ref);
  KpiTile k(String key, int n, {String? hint, String icon = 'activity'}) => KpiTile(label: f.t(key), value: '$n', hint: hint, icon: icon);
  switch (role) {
    case HomeRole.agent:
      final now = DateTime.now();
      return [
        k('an.k.newLeads', s.contacts.where((c) => c.status == LeadStatus.fresh).length, icon: 'account'),
        k('an.k.viewings', s.appointments.where((a) => a.status == AppointmentStatus.scheduled && a.kind == AppointmentKind.viewing && !a.at.isBefore(now)).length, icon: 'calendar'),
        k('an.k.followUps', s.contacts.where((c) => c.followUpOverdue(now)).length, icon: 'clock'),
      ];
    case HomeRole.developer:
      return [
        k('an.k.published', s.projects.where((p) => p.status == ProjectStatus.approved).length, icon: 'verified'),
        k('an.k.inReview', s.projects.where((p) => p.status == ProjectStatus.underReview).length, icon: 'clock'),
        k('an.k.contacts', s.events.length, icon: 'phone'),
      ];
    case HomeRole.construction:
      return [
        k('an.k.requests', s.events.length, icon: 'send'),
        k('an.k.awaiting', s.engagements.where((e) => e.state == EngagementState.awaitingMyConfirmation).length, icon: 'clock'),
        k('an.k.completed', s.engagements.where((e) => e.state == EngagementState.confirmedByBoth).length, icon: 'check'),
      ];
    case HomeRole.architecture:
    case HomeRole.interiorExterior:
      return [
        k('an.k.portfolio', s.portfolio.length, icon: 'architecture'),
        k('an.k.engagements', s.engagements.length, icon: 'verified'),
        k('an.k.contacts', s.events.length),
      ];
    case HomeRole.buyer:
      return const [];
  }
}

/// KPI strip + link, placed on each professional Home. Not shown to shoppers.
class RoleKpiStrip extends ConsumerWidget {
  final HomeRole role;

  /// Only the link to the analytics page (the agent dashboard already shows its own counts).
  final bool linkOnly;
  const RoleKpiStrip({super.key, required this.role, this.linkOnly = false});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final tiles = linkOnly ? const <KpiTile>[] : roleKpis(context, ref, role);
    if (tiles.isEmpty && !linkOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (tiles.isNotEmpty) KpiGrid(tiles: tiles),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AQTextButton(
              label: f.t('an.view'),
              color: c.accentDeep,
              trailingIcon: 'chevron-right',
              onPressed: () => context.push(analyticsRouteFor(role)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Analytics page of one role: a range selector, headline figures and a few honest charts.
class RoleAnalyticsScreen extends ConsumerStatefulWidget {
  final HomeRole role;
  const RoleAnalyticsScreen({super.key, required this.role});
  @override
  ConsumerState<RoleAnalyticsScreen> createState() => _RoleAnalyticsState();
}

class _RoleAnalyticsState extends ConsumerState<RoleAnalyticsScreen> {
  int _weeks = 8;
  int _metric = 0;

  List<String> _labels(BuildContext context, int n) {
    final now = DateTime.now();
    // Day and month only, so a label never wraps under the chart.
    return [
      for (var i = n - 1; i >= 0; i--)
        () {
          final d = now.subtract(Duration(days: 7 * i));
          return '${d.day}/${d.month}';
        }(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final role = widget.role;
    final s = _read(ref);
    final labels = _labels(context, _weeks);

    Widget unavailable(String key) => AnalyticsCard(
      title: f.t('an.c.$key'),
      child: Text(f.t('an.unavailable'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
    );

    final cards = <Widget>[];
    switch (role) {
      case HomeRole.agent:
        final byStatus = [
          for (final st in LeadStatus.values) (f.t('an.lead.${st.name}'), s.contacts.where((x) => x.status == st).length.toDouble()),
        ];
        final appts = [
          (f.t('an.appt.scheduled'), s.appointments.where((a) => a.status == AppointmentStatus.scheduled).length.toDouble()),
          (f.t('an.appt.done'), s.appointments.where((a) => a.status == AppointmentStatus.done).length.toDouble()),
          (f.t('an.appt.cancelled'), s.appointments.where((a) => a.status == AppointmentStatus.cancelled).length.toDouble()),
        ];
        final followDone = s.appointments.where((a) => a.kind == AppointmentKind.followUp && a.status == AppointmentStatus.done).length;
        final followAll = s.appointments.where((a) => a.kind == AppointmentKind.followUp && a.status != AppointmentStatus.cancelled).length;
        cards.addAll([
          AnalyticsCard(title: f.t('an.c.pipeline'), subtitle: f.t('an.c.pipeline.s'), child: AQBarChart(items: byStatus)),
          AnalyticsCard(title: f.t('an.c.viewings'), subtitle: f.t('an.c.viewings.s'), child: appts.every((e) => e.$2 == 0) ? Text(f.t('an.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true)) : AQDonut(parts: appts, centerLabel: f.t('an.total'))),
          AnalyticsCard(
            title: f.t('an.c.followups'),
            subtitle: f.t('an.c.followups.s'),
            child: followAll == 0
                ? Text(f.t('an.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true))
                : Text(f.t('an.followRate', {'done': '$followDone', 'all': '$followAll'}), style: AQTypography.of(context, AQText.titleMedium)),
          ),
        ]);
      case HomeRole.developer:
        final statuses = <ProjectStatus, String>{
          ProjectStatus.draft: f.t('an.proj.draft'),
          ProjectStatus.underReview: f.t('an.proj.review'),
          ProjectStatus.approved: f.t('an.proj.published'),
          ProjectStatus.changesRequested: f.t('an.proj.changes'),
        };
        final parts = [for (final e in statuses.entries) (e.value, s.projects.where((p) => p.status == e.key).length.toDouble())].where((e) => e.$2 > 0).toList();
        cards.addAll([
          AnalyticsCard(title: f.t('an.c.projects'), subtitle: f.t('an.c.projects.s'), child: parts.isEmpty ? Text(f.t('an.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true)) : AQDonut(parts: parts, centerLabel: f.t('an.total'))),
          s.eventsOk ? _contactChannels(context, f, s.events) : unavailable('contactChannels'),
        ]);
      case HomeRole.construction:
        cards.addAll([
          s.engagementsOk ? _engagements(context, f, s.engagements) : unavailable('engagements'),
          s.eventsOk ? _contactChannels(context, f, s.events) : unavailable('contactChannels'),
          AnalyticsCard(
            title: f.t('an.c.progress'),
            subtitle: f.t('an.c.progress.s'),
            note: f.t('an.sampleNote'),
            child: AQBarChart(items: [
              (f.t('an.stage.planning'), 3),
              (f.t('an.stage.building'), 5),
              (f.t('an.stage.finishing'), 2),
              (f.t('an.stage.handover'), 4),
            ]),
          ),
        ]);
      case HomeRole.architecture:
      case HomeRole.interiorExterior:
        final design = role == HomeRole.interiorExterior;
        cards.addAll([
          s.engagementsOk ? _engagements(context, f, s.engagements) : unavailable('engagements'),
          AnalyticsCard(
            title: f.t(design ? 'an.c.serviceInterest' : 'an.c.pipelineArc'),
            subtitle: f.t(design ? 'an.c.serviceInterest.s' : 'an.c.pipelineArc.s'),
            note: f.t('an.sampleNote'),
            child: AQBarChart(
              items: design
                  ? [(f.t('an.svc.interior'), 9), (f.t('an.svc.exterior'), 5)]
                  : [(f.t('an.stage.brief'), 4), (f.t('an.stage.concept'), 3), (f.t('an.stage.permits'), 2), (f.t('an.stage.site'), 2)],
            ),
          ),
        ]);
      case HomeRole.buyer:
        break;
    }

    // The time series of this role: one or two measures, twenty-four sample weeks each so the previous
    // period can be compared. They are invented sample events, said so on the card.
    final series = switch (role) {
      HomeRole.agent => const [('leads', 'leads', 6.0, 6.0), ('listingViews', 'views', 40.0, 30.0)],
      HomeRole.developer => const [('enquiries', 'enq', 7.0, 7.0), ('projectInterest', 'interest', 30.0, 25.0)],
      HomeRole.construction => const [('requests', 'req', 5.0, 5.0)],
      HomeRole.architecture || HomeRole.interiorExterior => const [('portfolioViews', 'pviews', 25.0, 20.0), ('enquiries', 'enq', 4.0, 5.0)],
      HomeRole.buyer => const <(String, String, double, double)>[],
    };
    final mi = _metric.clamp(0, series.isEmpty ? 0 : series.length - 1);
    Widget hero = const SizedBox.shrink();
    if (series.isNotEmpty) {
      final (key, seed, base, amp) = series[mi];
      final all = sampleWeekly('${roleKey(role)}-$seed', base: base, amp: amp, weeks: 24);
      final cur = all.sublist(all.length - _weeks);
      final sumCur = cur.fold<double>(0, (a, b) => a + b);
      hero = Container(
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: BorderRadius.circular(AQRadius.large),
          border: Border.all(color: c.hairline),
          boxShadow: [BoxShadow(color: c.ink.withValues(alpha: c.isDark ? 0 : 0.05), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (series.length > 1) ...[
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (i, e) in series.indexed) AQChoicePillCompact(label: f.t('an.c.${e.$1}'), selected: i == mi, onTap: () => setState(() => _metric = i)),
            ]),
            const SizedBox(height: AQSpacing.x3),
          ],
          Semantics(header: true, child: Text(f.t('an.c.$key'), style: AQTypography.of(context, AQText.titleMedium))),
          Text(f.t('an.c.$key.s'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
          const SizedBox(height: AQSpacing.x3),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text('${sumCur.round()}', style: AQTypography.of(context, AQText.displaySmall)),
            const SizedBox(width: AQSpacing.x2),
            Flexible(child: Text(f.t('an.inPeriod', {'n': '$_weeks'}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
          ]),
          const SizedBox(height: AQSpacing.x3),
          AQColumnChart(values: cur, labels: labels, semanticsLabel: '${f.t('an.c.$key')}: ${cur.map((e) => e.round()).join(', ')}'),
          const SizedBox(height: AQSpacing.x2),
          Text('${f.t('an.tapHint')} ${f.t('an.sampleNote')}', style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
        ]),
      );
    }
    final now = DateTime.now();
    final start = now.subtract(Duration(days: 7 * _weeks));
    return DbShellPage(
      eyebrow: f.t('an.eyebrow'),
      title: f.t('an.title'),
      subtitle: f.t('an.subtitle'),
      children: [
        Row(children: [
          Expanded(child: Text(f.t('an.range', {'n': '$_weeks', 'a': VFmt.shortDate(context, start), 'b': VFmt.shortDate(context, now)}), style: AQTypography.of(context, AQText.bodySmall, soft: true))),
          if (kDemoMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(12)),
              child: Text(f.t('an.sampleChip'), style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
            ),
        ]),
        const SizedBox(height: AQSpacing.x3),
        AQPeriodSwitch(values: const [4, 8, 12], selected: _weeks, labelOf: (w) => f.t('an.weeks', {'n': '$w'}), onChanged: (w) => setState(() => _weeks = w)),
        const SizedBox(height: AQSpacing.x4),
        KpiGrid(tiles: roleKpis(context, ref, role)),
        const SizedBox(height: AQSpacing.x2),
        Text(f.t('an.liveNote'), style: AQTypography.of(context, AQText.labelSmall, color: c.inkFaint)),
        const SizedBox(height: AQSpacing.x4),
        hero,
        const SizedBox(height: AQSpacing.x3),
        LayoutBuilder(
          builder: (context, box) {
            final two = box.maxWidth >= 760;
            const gap = AQSpacing.x3;
            if (!two) {
              return Column(children: [for (final w in cards) Padding(padding: const EdgeInsets.only(bottom: gap), child: w)]);
            }
            final w = (box.maxWidth - gap) / 2;
            return Wrap(spacing: gap, runSpacing: gap, children: [for (final x in cards) SizedBox(width: w, child: x)]);
          },
        ),
      ],
    );
  }

  Widget _contactChannels(BuildContext context, FlowStrings f, List<ContactEvent> events) {
    final call = events.where((e) => e.channel == ContactChannel.call).length.toDouble();
    final wa = events.where((e) => e.channel == ContactChannel.whatsapp).length.toDouble();
    return AnalyticsCard(
      title: f.t('an.c.contactChannels'),
      subtitle: f.t('an.c.contactChannels.s'),
      child: events.isEmpty ? Text(f.t('an.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true)) : AQBarChart(items: [(f.t('an.ch.call'), call), (f.t('an.ch.whatsapp'), wa)]),
    );
  }

  Widget _engagements(BuildContext context, FlowStrings f, List<Engagement> list) {
    final parts = [
      (f.t('an.eng.awaitingMe'), list.where((e) => e.state == EngagementState.awaitingMyConfirmation).length.toDouble()),
      (f.t('an.eng.awaitingClient'), list.where((e) => e.state == EngagementState.awaitingClient).length.toDouble()),
      (f.t('an.eng.confirmed'), list.where((e) => e.state == EngagementState.confirmedByBoth).length.toDouble()),
    ].where((e) => e.$2 > 0).toList();
    return AnalyticsCard(
      title: f.t('an.c.engagements'),
      subtitle: f.t('an.c.engagements.s'),
      child: parts.isEmpty ? Text(f.t('an.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true)) : AQDonut(parts: parts, centerLabel: f.t('an.total')),
    );
  }
}

/// A sliding capsule for choosing one of a few periods. The thumb moves under the selection; the choice
/// is real (the owner redraws every figure and chart for it).
class AQPeriodSwitch extends StatelessWidget {
  final List<int> values;
  final int selected;
  final String Function(int) labelOf;
  final ValueChanged<int> onChanged;
  const AQPeriodSwitch({super.key, required this.values, required this.selected, required this.labelOf, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final i = values.indexOf(selected).clamp(0, values.length - 1);
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(22), border: Border.all(color: c.hairline)),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / values.length;
          return Stack(children: [
            AnimatedPositionedDirectional(
              duration: AQMotion.scaled(context, const Duration(milliseconds: 220)),
              curve: Curves.easeInOutCubic,
              start: w * i,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(20))),
            ),
            Row(children: [
              for (final v in values)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: v == selected,
                    label: labelOf(v),
                    excludeSemantics: true,
                    onTap: () => onChanged(v),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        AQHaptics.selection();
                        onChanged(v);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AQMotion.scaled(context, const Duration(milliseconds: 200)),
                          style: AQTypography.of(context, AQText.labelLarge, color: v == selected ? c.onAccent : c.inkSoft),
                          child: Text(labelOf(v)),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ]);
        },
      ),
    );
  }
}

/// A compact selectable chip used for the range choice.
class AQChoicePillCompact extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const AQChoicePillCompact({super.key, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      selected: selected,
      onFocus: () {},
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: AQMotion.scaled(context, AQMotion.fast),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? c.accent : c.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? c.accent : c.hairline),
          ),
          child: Center(
            widthFactor: 1,
            child: Text(label, style: AQTypography.of(context, AQText.labelMedium, color: selected ? c.onAccent : c.ink)),
          ),
        ),
      ),
    );
  }
}

/// `/pro/analytics`: the analytics of whichever professional role is signed in.
class ProAnalyticsScreen extends ConsumerWidget {
  const ProAnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      RoleAnalyticsScreen(role: ref.watch(homeResolutionProvider).role);
}
