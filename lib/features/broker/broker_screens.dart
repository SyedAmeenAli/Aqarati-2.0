import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_status.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/backend_mode.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_widgets.dart' show DbErrorCard, DbNotice;
import '../leads/phone_launcher.dart';
import '../viewing/domain/viewing_presentation.dart' show AQTone;
import '../viewing/screens/viewing_kit.dart'
    show AQViewingSectionTitle, AQViewingSkeleton;
import '../viewing/widgets/viewing_components.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show AQResultCard, aqAllPropertiesProvider;
import '../workspace/aq_thumb.dart';
import 'broker_repository.dart';

/// The badge. Only ever drawn for a broker the service returned as approved.
class AqaratiBrokerBadge extends StatelessWidget {
  const AqaratiBrokerBadge({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return AQStatusPill(
      label: f.t('br.badge'),
      tone: AQTone.success,
      icon: 'verified',
      dense: true,
    );
  }
}

// ------------------------------------------------------------------ introduction

class BrokerIntroScreen extends StatelessWidget {
  const BrokerIntroScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/app/home');
    return AQViewingScaffold(
      title: f.t('br.title'),
      subtitle: f.t('br.sub'),
      backLabel: f.t('common.back'),
      onBack: back,
      bottom: AQBottomActionBar(
        primary: AQPrimaryButton(
          label: f.t('br.find'),
          trailingChevron: false,
          onPressed: () => context.push('/broker/list'),
        ),
      ),
      children: [
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: AqaratiBrokerBadge(),
        ),
        AQViewingSectionTitle(f.t('br.what.t')),
        Text(
          f.t('br.what.b'),
          style: AQTypography.of(context, AQText.bodyMedium),
        ),
        AQViewingSectionTitle(f.t('br.how.t')),
        AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 1; i <= 3; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AQSpacing.x1),
                  child: Text(
                    '$i. ${f.t('br.how.$i')}',
                    style: AQTypography.of(context, AQText.bodyMedium),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x4),
        AQNoticeCard(
          icon: 'info',
          title: f.t('br.not.t'),
          body: f.t('br.not.b'),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQSecondaryButton(
          label: f.t('br.sell.cta'),
          trailingChevron: false,
          onPressed: () => context.push('/sell'),
        ),
        const SizedBox(height: AQSpacing.x4),
        if (kUseDemoBackend) DbNotice(f.t('br.demo'), icon: 'info'),
      ],
    );
  }
}

// ------------------------------------------------------------------ directory

class BrokerListScreen extends ConsumerWidget {
  const BrokerListScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/broker');
    return AQViewingScaffold(
      title: f.t('br.list.title'),
      subtitle: f.t('br.sub'),
      backLabel: f.t('common.back'),
      onBack: back,
      children: [
        ref
            .watch(brokersProvider)
            .when(
              loading: () => const Column(
                children: [
                  AQViewingSkeleton(height: 84),
                  AQViewingSkeleton(height: 84),
                ],
              ),
              error: (e, _) => DbErrorCard(
                error: e,
                onRetry: () => ref.invalidate(brokersProvider),
              ),
              data: (list) => list.isEmpty
                  ? AQEmptyViewingState(
                      title: f.t('br.list.empty.t'),
                      body: f.t('br.list.empty.b'),
                    )
                  : Column(
                      children: [
                        for (final b in list)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AQSpacing.x3,
                            ),
                            child: _BrokerCard(b),
                          ),
                      ],
                    ),
            ),
        const SizedBox(height: AQSpacing.x4),
        if (kUseDemoBackend) DbNotice(f.t('br.demo'), icon: 'info'),
      ],
    );
  }
}

class _BrokerCard extends StatelessWidget {
  final AqaratiBroker b;
  const _BrokerCard(this.b);
  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${b.name}, ${f.t('br.badge')}',
      excludeSemantics: true,
      onTap: () => context.push('/broker/${b.id}'),
      child: AQPressable(
        onTap: () => context.push('/broker/${b.id}'),
        child: AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x4),
          child: Row(
            children: [
              aqRowLead(AQThumb(monogramOf: b.name)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      VFmt.iso(b.name),
                      style: AQTypography.of(context, AQText.titleSmall),
                    ),
                    if (b.area.isNotEmpty)
                      Text(
                        VFmt.iso(b.area),
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      ),
                    const SizedBox(height: AQSpacing.x2),
                    const AqaratiBrokerBadge(),
                  ],
                ),
              ),
              const AQIcon('chevron-right', size: 18, directional: true),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ profile

class BrokerProfileScreen extends ConsumerStatefulWidget {
  final String id;
  const BrokerProfileScreen({super.key, required this.id});
  @override
  ConsumerState<BrokerProfileScreen> createState() => _ProfileState();
}

class _ProfileState extends ConsumerState<BrokerProfileScreen> {
  String? _callKey;

  Future<void> _call(AqaratiBroker b) async {
    setState(() => _callKey = null);
    final ok = await ref.read(phoneLauncherProvider).dial(b.phone!);
    if (!ok && mounted) setState(() => _callKey = 'br.p.callFail');
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    void back() => aqBack(context, '/broker/list');
    Widget shell(List<Widget> children, {String? title}) => AQViewingScaffold(
      title: title ?? f.t('br.p.title'),
      backLabel: f.t('common.back'),
      onBack: back,
      children: children,
    );
    return ref
        .watch(brokerProvider(widget.id))
        .when(
          loading: () => shell(const [AQViewingSkeleton(height: 96)]),
          error: (e, _) => shell([
            DbErrorCard(
              error: e,
              onRetry: () => ref.invalidate(brokerProvider(widget.id)),
            ),
          ]),
          data: (b) {
            if (b == null) {
              return shell([
                AQNoticeCard(
                  icon: 'info',
                  title: f.t('br.p.notFound'),
                  body: '',
                ),
                const SizedBox(height: AQSpacing.x3),
                AQPrimaryButton(
                  label: f.t('br.p.back'),
                  trailingChevron: false,
                  onPressed: back,
                ),
              ]);
            }
            final props = ref.watch(aqAllPropertiesProvider).valueOrNull ?? [];
            final linked = props
                .where((p) => b.propertyIds.contains(p.id))
                .toList();
            return AQViewingScaffold(
              title: VFmt.iso(b.name),
              subtitle: b.area.isEmpty ? null : VFmt.iso(b.area),
              backLabel: f.t('common.back'),
              onBack: back,
              children: [
                const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AqaratiBrokerBadge(),
                ),
                const SizedBox(height: AQSpacing.x3),
                if (_callKey != null) AQErrorBanner(text: f.t(_callKey!)),
                if (b.phone == null)
                  DbNotice(f.t('br.p.noPhone'), icon: 'phone')
                else ...[
                  AQPrimaryButton(
                    label: f.t('br.p.call'),
                    leadingIcon: 'phone',
                    trailingChevron: false,
                    onPressed: () => _call(b),
                  ),
                  const SizedBox(height: AQSpacing.x1),
                  Text(
                    f.t('br.p.callNote'),
                    style: AQTypography.of(
                      context,
                      AQText.bodySmall,
                      soft: true,
                    ),
                  ),
                ],
                AQViewingSectionTitle(f.t('br.p.about')),
                Text(
                  b.about.isEmpty ? f.t('br.p.noAbout') : b.about,
                  style: AQTypography.of(context, AQText.bodyMedium),
                ),
                AQViewingSectionTitle(f.t('br.p.listings')),
                if (linked.isEmpty)
                  DbNotice(f.t('br.p.noListings'), icon: 'info')
                else
                  for (final p in linked)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                      child: Column(
                        children: [
                          AQResultCard(property: p),
                          const SizedBox(height: AQSpacing.x1),
                          AQTextButton(
                            label: f.t('br.p.viewing'),
                            color: AQColors.of(context).accent,
                            onPressed: () =>
                                context.push('/property/${p.id}/viewing'),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: AQSpacing.x4),
                if (kUseDemoBackend) DbNotice(f.t('br.demo'), icon: 'info'),
              ],
            );
          },
        );
  }
}
