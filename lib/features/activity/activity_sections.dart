import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/aq/aq_status.dart';
import '../devbuild/db_widgets.dart' show DbErrorCard;
import '../ebroker/ebroker_repository.dart';
import '../ebroker/ebroker_screens.dart' show EBrokerStatusPill;
import '../engagement/engagement_models.dart';
import '../engagement/engagement_repository.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart' show AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_scaffold.dart' show AQShellInset;
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_thumb.dart';

/// One record in an Activity list: a title, one line of context, its status and a way in.
class _Row extends StatelessWidget {
  final String title, line, label;
  final Widget status;
  final String path;
  final Widget? lead;
  const _Row({
    required this.title,
    required this.line,
    required this.status,
    required this.path,
    required this.label,
    this.lead,
  });
  @override
  Widget build(BuildContext context) {
    void open() => context.push(path);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
      child: Semantics(
        button: true,
        focusable: true,
        onFocus: () {},
        label: label,
        excludeSemantics: true,
        onTap: open,
        child: AQPressable(
          onTap: open,
          child: AQSurface(
            padding: const EdgeInsets.all(AQSpacing.x4),
            child: Row(
              children: [
                if (lead != null) aqRowLead(lead!),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AQTypography.of(context, AQText.titleSmall),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      ),
                      const SizedBox(height: AQSpacing.x2),
                      status,
                    ],
                  ),
                ),
                const AQIcon('chevron-right', size: 18, directional: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _page(BuildContext context, List<Widget> children) => SingleChildScrollView(
  padding: EdgeInsets.fromLTRB(
    AQSpacing.gutter,
    AQSpacing.x4,
    AQSpacing.gutter,
    AQSpacing.x6 + AQShellInset.of(context) + 44,
  ),
  child: Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  ),
);

/// Property-submission status (Aqary e-Broker): what was sent, and where it stands.
class SubmissionsView extends ConsumerWidget {
  const SubmissionsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final async = ref.watch(myEBrokerProvider);
    return _page(context, [
      async.when(
        loading: () => const AQViewingSkeleton(height: 96),
        error: (e, _) => DbErrorCard(
          error: e,
          onRetry: () => ref.invalidate(myEBrokerProvider),
        ),
        data: (all) => all.isEmpty
            ? AQEmptyViewingState(
                icon: 'development',
                title: f.t('eb.mine.none.t'),
                body: f.t('eb.mine.none.b'),
                steps: [f.t('emp.sell.1'), f.t('emp.sell.2'), f.t('emp.sell.3')],
              )
            : Column(
                children: [
                  for (final s in all)
                    _Row(
                      title: VFmt.iso(s.input.title),
                      line: VFmt.iso(s.input.wilayat),
                      status: EBrokerStatusPill(s.status),
                      lead: AQThumb(asset: propertyTypeImage(s.input.type)),
                      path: '/sell/${s.id}',
                      label:
                          '${s.input.title}, ${f.t('eb.st.${s.status.name}')}',
                    ),
                ],
              ),
      ),
      const SizedBox(height: AQSpacing.x2),
      AQSecondaryButton(
        label: f.t('eb.start'),
        trailingChevron: false,
        onPressed: () => context.push('/sell'),
      ),
    ]);
  }
}

String _typeKey(String t) => switch (t) {
  'development' => 'pro.developers',
  'interior_exterior' => 'pro.interior',
  'architecture' => 'pro.architecture',
  _ => 'pro.construction',
};

/// Requests made to professionals (construction, development, architecture, design).
class RequestsView extends ConsumerWidget {
  const RequestsView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final async = ref.watch(engagementsProvider);
    final now = DateTime.now();
    return _page(context, [
      async.when(
        loading: () => const AQViewingSkeleton(height: 96),
        error: (e, _) => DbErrorCard(
          error: e,
          onRetry: () => ref.invalidate(engagementsProvider),
        ),
        data: (all) => all.isEmpty
            ? AQEmptyViewingState(
                icon: 'verified',
                title: f.t('ce.list.empty.t'),
                body: f.t('ce.list.empty.b'),
                steps: [f.t('emp.eng.1'), f.t('emp.eng.2'), f.t('emp.eng.3')],
              )
            : Column(
                children: [
                  for (final e in all)
                    _Row(
                      title: VFmt.iso(e.professionalName),
                      line: f.t(_typeKey(e.professionalType)),
                      status: AQStatusPill(
                        label: f.t('ce.ph.${e.phaseAt(now).name}'),
                        tone: e.phaseAt(now) == EngagementPhase.confirmed
                            ? AQTone.success
                            : AQTone.neutral,
                      ),
                      lead: AQThumb(asset: businessCoverById(e.professionalId), monogramOf: e.professionalName),
                      path: '/engagements/${e.id}',
                      label:
                          '${e.professionalName}, ${f.t('ce.ph.${e.phaseAt(now).name}')}',
                    ),
                ],
              ),
      ),
    ]);
  }
}
