import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../../data/repositories/providers.dart';
import '../flow/widgets/flow_common.dart' show AQSkeleton;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show aqImg;

final _compareProvider = FutureProvider.autoDispose
    .family<List<Property>, String>((ref, ids) async {
      final all = await ref.watch(propertyRepositoryProvider).search();
      return [
        for (final id in ids.split(','))
          ...all.where((p) => p.id == id).take(1),
      ];
    });

/// Side-by-side facts for the properties picked in Saved. Every value comes from the listing; a
/// missing value reads "Not listed" instead of a dash.
class CompareScreen extends ConsumerWidget {
  final List<String> propertyIds;
  const CompareScreen({super.key, required this.propertyIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final data = ref.watch(_compareProvider(propertyIds.join(',')));
    final count = data.valueOrNull?.length;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return AQViewingScaffold(
      maxWidth: wide ? 1180 : null,
      title: f.t('cmp.title'),
      subtitle: count == null
          ? null
          : f.t('cmp.sub', {'n': VFmt.n(context, count)}),
      backLabel: f.t('common.back'),
      onBack: () => Navigator.of(context).maybePop(),
      children: [
        data.when(
          loading: () => const AQSkeleton(),
          error: (_, _) => _Note(icon: 'alert', text: f.t('cmp.err')),
          data: (list) => list.isEmpty
              ? _Note(
                  icon: 'info',
                  title: f.t('cmp.empty.t'),
                  text: f.t('cmp.empty.b'),
                )
              : wide
                  ? IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0) const SizedBox(width: AQSpacing.x4),
                            Expanded(child: _Column(property: list[i])),
                          ],
                        ],
                      ),
                    )
                  : _PhoneCompare(list: list),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final String icon, text;
  final String? title;
  const _Note({required this.icon, required this.text, this.title});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AQSurface(
      padding: const EdgeInsets.all(AQSpacing.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AQIcon(icon, size: AQIconSize.medium, color: c.accent),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: AQTypography.of(context, AQText.titleMedium),
                  ),
                if (title != null) const SizedBox(height: AQSpacing.x1),
                Text(
                  text,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    soft: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final Property property;
  const _Column({required this.property});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final p = property;
    final na = f.t('cmp.na');
    String n(num? v, [String suffix = '']) =>
        v == null ? na : '${VFmt.n(context, v.round())}$suffix';
    String txLabel() => switch (p.transactionType) {
      TransactionType.buy => f.t('cmp.tx.buy'),
      TransactionType.rent => f.t('cmp.tx.rent'),
      TransactionType.lease => f.t('cmp.tx.lease'),
    };
    Widget row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AQTypography.of(context, AQText.bodySmall, soft: true),
            ),
          ),
          const SizedBox(width: AQSpacing.x2),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AQTypography.of(context, AQText.bodyMedium),
            ),
          ),
        ],
      ),
    );
    return SizedBox(
      child: AQSurface(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AQRadius.medium),
              ),
              child: AspectRatio(
                aspectRatio: 1.5,
                child: ExcludeSemantics(
                  child: p.imageUrls.isEmpty
                      ? ColoredBox(color: c.surfaceSelected)
                      : aqImg(p.imageUrls.first, cacheWidth: 520),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AQSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header rows keep one height in every column so the attribute rows below line up.
                    Padding(
                      padding: const EdgeInsets.only(bottom: AQSpacing.x2),
                      child: Opacity(
                        opacity: p.verification.status == VerificationStatus.verified ? 1 : 0,
                        child: ExcludeSemantics(
                          excluding: p.verification.status != VerificationStatus.verified,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AQIcon('verified', size: 16, color: c.accent),
                              const SizedBox(width: 6),
                              Flexible(child: Text(f.t('cmp.verified'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        p.priceLabel,
                        maxLines: 1,
                        softWrap: false,
                        style: AQTypography.of(
                          context,
                          AQText.titleLarge,
                          color: c.accentDeep,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(44),
                      child: Text(
                        VFmt.iso(p.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(context, AQText.titleSmall),
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      height: MediaQuery.textScalerOf(context).scale(40),
                      child: Text(
                        VFmt.iso(p.locationLabel),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AQTypography.of(context, AQText.bodySmall, soft: true),
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    Divider(height: 1, color: c.hairline),
                    const SizedBox(height: AQSpacing.x2),
                    row(
                      f.t('cmp.type'),
                      FlowStrings.keys.contains('ptype.${p.type.name}')
                          ? f.t('ptype.${p.type.name}')
                          : p.type.label,
                    ),
                    row(f.t('cmp.beds'), n(p.bedrooms)),
                    row(f.t('cmp.baths'), n(p.bathrooms)),
                    row(f.t('cmp.area'), n(p.areaSqm, ' m²')),
                    row(f.t('cmp.parking'), n(p.parkingSpaces)),
                    row(f.t('cmp.tx'), txLabel()),
                    const SizedBox(height: AQSpacing.x2),
                    Divider(height: 1, color: c.hairline),
                    const SizedBox(height: AQSpacing.x3),
                    Text(
                      f.t('cmp.amen'),
                      style: AQTypography.of(
                        context,
                        AQText.labelMedium,
                        color: c.inkSoft,
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x2),
                    if (p.amenities.isEmpty)
                      Text(
                        f.t('cmp.none'),
                        style: AQTypography.of(
                          context,
                          AQText.bodySmall,
                          soft: true,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final a in p.amenities)
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: c.surfaceSelected,
                                borderRadius: BorderRadius.circular(
                                  AQRadius.small,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AQSpacing.x2,
                                  vertical: 5,
                                ),
                                child: Text(
                                  a,
                                  style: AQTypography.of(
                                    context,
                                    AQText.labelMedium,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    const Spacer(),
                    const SizedBox(height: AQSpacing.x4),
                    AQSecondaryButton(
                      label: f.t('cmp.open'),
                      trailingChevron: false,
                      onPressed: () => context.push('/property/${p.id}'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Phone layout: one header card per property (lettered), then a single table whose columns carry the same
/// letters. Nothing is dropped; the table scrolls sideways, with a visible hint, only when it cannot fit.
class _PhoneCompare extends StatelessWidget {
  final List<Property> list;
  const _PhoneCompare({required this.list});

  static const _labelW = 92.0;
  static const _minCol = 84.0;

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final na = f.t('cmp.na');
    String n(num? v, [String suffix = '']) => v == null ? na : '${VFmt.n(context, v.round())}$suffix';
    String tx(Property p) => switch (p.transactionType) {
          TransactionType.buy => f.t('cmp.tx.buy'),
          TransactionType.rent => f.t('cmp.tx.rent'),
          TransactionType.lease => f.t('cmp.tx.lease'),
        };
    String letter(int i) => String.fromCharCode(65 + i);
    Widget badge(int i) => Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
          child: Text(letter(i), style: AQTypography.of(context, AQText.labelMedium, color: Colors.white)),
        );
    final rows = <(String, List<String>)>[
      (f.t('cmp.price'), [for (final p in list) p.priceLabel]),
      (f.t('cmp.type'), [for (final p in list) FlowStrings.keys.contains('ptype.${p.type.name}') ? f.t('ptype.${p.type.name}') : p.type.label]),
      (f.t('cmp.tx'), [for (final p in list) tx(p)]),
      (f.t('cmp.beds'), [for (final p in list) n(p.bedrooms)]),
      (f.t('cmp.baths'), [for (final p in list) n(p.bathrooms)]),
      (f.t('cmp.area'), [for (final p in list) n(p.areaSqm, ' m²')]),
      (f.t('cmp.parking'), [for (final p in list) n(p.parkingSpaces)]),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < list.length; i++) ...[
        AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.medium),
                child: SizedBox(
                  width: 96,
                  height: 72,
                  child: ExcludeSemantics(child: list[i].imageUrls.isEmpty ? ColoredBox(color: c.surfaceSelected) : aqImg(list[i].imageUrls.first, cacheWidth: 300)),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // One line always: on the narrowest phones the price scales down a little instead of wrapping "OMR" from its figure.
                  Row(children: [
                    badge(i),
                    const SizedBox(width: AQSpacing.x2),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(list[i].priceLabel, maxLines: 1, softWrap: false, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(VFmt.iso(list[i].title), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                  Text(VFmt.iso(list[i].locationLabel), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                ]),
              ),
            ]),
            if (list[i].verification.status == VerificationStatus.verified) ...[
              const SizedBox(height: AQSpacing.x2),
              Row(children: [AQIcon('verified', size: 16, color: c.accent), const SizedBox(width: 6), Flexible(child: Text(f.t('cmp.verified'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)))]),
            ],
            const SizedBox(height: AQSpacing.x3),
            AQSecondaryButton(label: f.t('cmp.open'), trailingChevron: false, compact: true, onPressed: () => context.push('/property/${list[i].id}')),
          ]),
        ),
        const SizedBox(height: AQSpacing.x3),
      ],
      LayoutBuilder(builder: (context, box) {
        final need = _labelW + list.length * _minCol;
        final overflow = need > box.maxWidth;
        final colW = overflow ? _minCol : (box.maxWidth - _labelW - AQSpacing.x3 * 2) / list.length;
        Widget cell(Widget child, {bool head = false}) => SizedBox(width: colW, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), child: child));
        Widget lbl(String t) => SizedBox(width: _labelW, child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: AQTypography.of(context, AQText.bodySmall, soft: true))));
        final table = AQSurface(
          padding: const EdgeInsets.all(AQSpacing.x3),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [SizedBox(width: _labelW), for (var i = 0; i < list.length; i++) cell(Align(alignment: AlignmentDirectional.centerStart, child: badge(i)))]),
            Divider(height: 1, color: c.hairline),
            for (final r in rows) ...[
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [lbl(r.$1), for (final v in r.$2) cell(Text(v, style: AQTypography.of(context, AQText.bodySmall)))]),
              Divider(height: 1, color: c.hairline),
            ],
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              lbl(f.t('cmp.amen')),
              for (final p in list)
                cell(p.amenities.isEmpty
                    ? Text(f.t('cmp.none'), style: AQTypography.of(context, AQText.bodySmall, soft: true))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final a in p.amenities) Padding(padding: const EdgeInsets.only(bottom: 4), child: Text(a, style: AQTypography.of(context, AQText.bodySmall)))])),
            ]),
          ]),
        );
        if (!overflow) return table;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x2),
            child: Row(children: [AQIcon('chevron-right', size: 16, color: c.inkFaint, directional: true), const SizedBox(width: 4), Flexible(child: Text(f.t('cmp.swipe'), style: AQTypography.of(context, AQText.bodySmall, soft: true)))]),
          ),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: table),
        ]);
      }),
    ]);
  }
}
