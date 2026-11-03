import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/providers.dart';
import '../search/aq_filter_sheet.dart';
import '../search/aq_search.dart' show AQQueryField;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_cards.dart' show AQProfessionalCard, AQResultGrid, aqListMaxWidth;
import '../workspace/aq_home.dart' show AQSkeletonBox, AQNoticeLine;

/// Professionals directory: developers, builders, architects, designers, agents and
/// maintenance providers. Opens a profile on tap.
class AQProfessionalsScreen extends ConsumerStatefulWidget {
  final String? query;
  final String? category;
  const AQProfessionalsScreen({super.key, this.query, this.category});
  @override
  ConsumerState<AQProfessionalsScreen> createState() => _AQProfessionalsScreenState();
}

class _AQProfessionalsScreenState extends ConsumerState<AQProfessionalsScreen> {
  late final _ctl = TextEditingController(text: widget.query ?? '');
  late BusinessCategory? _cat = BusinessCategory.values.where((c) => c.name == widget.category).firstOrNull;
  bool _verified = false;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(businessesProvider);
    final q = _ctl.text.trim().toLowerCase();
    // The page says what was asked for: Maintenance is not the generic professionals list.
    final maint = _cat == BusinessCategory.maintenance;
    return AQViewingScaffold(
      maxWidth: aqListMaxWidth(context) == null ? null : aqListMaxWidth(context)! + AQSpacing.gutter * 2,
      title: maint ? f.t('pro.maint.t') : (_cat == null ? f.t('pro.title') : f.t('bcat.${_cat!.name}')),
      subtitle: maint ? f.t('pro.maint.s') : f.t('pro.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/explore'),
      children: [
        AQQueryField(controller: _ctl, hint: f.t('pro.search'), onChanged: (_) => setState(() {}), onSubmitted: (_) => setState(() {})),
        const SizedBox(height: AQSpacing.x4),
        // One scrolling line of categories (not a four-row cloud), like the other discovery filters.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            AQChoicePill(label: f.t('flt.all'), selected: _cat == null, onTap: () => setState(() => _cat = null)),
            for (final k in BusinessCategory.values) ...[
              const SizedBox(width: AQSpacing.x2),
              AQChoicePill(label: f.t('bcat.${k.name}'), selected: _cat == k, onTap: () => setState(() => _cat = _cat == k ? null : k)),
            ],
          ]),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQCheckToggle(label: f.t('pro.verified'), value: _verified, onChanged: (v) => setState(() => _verified = v)),
        const SizedBox(height: AQSpacing.x4),
        async.when(
          loading: () => const Column(children: [AQSkeletonBox(height: 140), SizedBox(height: AQSpacing.x3), AQSkeletonBox(height: 140)]),
          error: (_, _) => AQErrorBanner(text: f.t('pro.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(businessesProvider))),
          data: (all) {
            final shown = [
              for (final b in all)
                if ((q.isEmpty || '${b.name} ${b.description} ${b.categories.map((x) => x.label).join(' ')}'.toLowerCase().contains(q)) && (_cat == null || b.categories.contains(_cat)) && (!_verified || b.verification.isVerified)) b,
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: Semantics(liveRegion: true, child: Text(f.t('pro.count', {'n': VFmt.n(context, shown.length)}), style: AQTypography.of(context, AQText.headlineSmall)))),
              if (shown.isEmpty)
                Column(children: [AQNoticeLine(text: f.t('pro.empty')), if (_cat != null || _verified || q.isNotEmpty) AQSecondaryButton(label: f.t('flt.clear'), trailingChevron: false, onPressed: () => setState(() {
                          _cat = null;
                          _verified = false;
                          _ctl.clear();
                        }))])
              else
                AQResultGrid(children: [for (final b in shown) _ProCard(business: b)]),
            ]);
          },
        ),
      ],
    );
  }
}

class _ProCard extends StatelessWidget {
  final Business business;
  const _ProCard({required this.business});

  @override
  Widget build(BuildContext context) => AQProfessionalCard(business: business, detailed: true);
}
