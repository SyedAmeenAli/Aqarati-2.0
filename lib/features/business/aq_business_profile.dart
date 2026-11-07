import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart' show BusinessCategory;
import '../../data/repositories/providers.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../contact/contact_actions.dart';
import '../workspace/aq_cards.dart' show aqListMaxWidth;
import '../workspace/aq_thumb.dart' show AQThumb;
import '../workspace/aq_home.dart' show aqImg, aqAllPropertiesProvider, AQResultCard, AQSkeletonBox;

final aqBusinessProvider = FutureProvider.autoDispose.family<Business?, String>((ref, id) => ref.watch(businessRepositoryProvider).getById(id));

class AQBusinessProfileScreen extends ConsumerWidget {
  final String businessId;
  const AQBusinessProfileScreen({super.key, required this.businessId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(aqBusinessProvider(businessId));
    void back() => aqBack(context, '/professionals');
    return async.when(
      loading: () => AQViewingScaffold(backLabel: f.t('common.back'), onBack: back, children: const [AQSkeletonBox(height: 220), SizedBox(height: AQSpacing.x4), AQSkeletonBox(height: 120)]),
      error: (_, _) => AQViewingScaffold(
        backLabel: f.t('common.back'),
        onBack: back,
        children: [AQErrorBanner(text: f.t('bp.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqBusinessProvider(businessId))))],
      ),
      data: (b) => b == null
          ? AQViewingScaffold(title: f.t('bp.notFound'), backLabel: f.t('common.back'), onBack: back, children: [AQSecondaryButton(label: f.t('bp.browse'), trailingChevron: false, onPressed: () => context.go('/professionals'))])
          : _Profile(business: b, onBack: back),
    );
  }
}

class _Profile extends ConsumerWidget {
  final Business business;
  final VoidCallback onBack;
  const _Profile({required this.business, required this.onBack});

  Widget _head(BuildContext context, String text, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
        child: LayoutBuilder(
          builder: (context, box) => Row(children: [
            Expanded(child: Semantics(header: true, child: Text(text, style: AQTypography.of(context, AQText.headlineMedium)))),
            // A long trailing action scales down instead of pushing the heading out of the row.
            if (trailing != null) ConstrainedBox(constraints: BoxConstraints(maxWidth: box.maxWidth * 0.5), child: FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerEnd, child: trailing)),
          ]),
        ),
      );

  Widget _info(BuildContext context, String icon, String text) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AQSpacing.x1),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 2), child: AQIcon(icon, size: 16, color: c.accent)),
        const SizedBox(width: AQSpacing.x2),
        Expanded(child: Text(VFmt.iso(text), style: AQTypography.of(context, AQText.bodyMedium, soft: true))),
      ]),
    );
  }

  void _photo(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xDD000000),
      animationStyle: AnimationStyle(duration: AQMotion.dialog, reverseDuration: AQMotion.fast, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic),
      builder: (d) => Stack(children: [
        Positioned.fill(child: GestureDetector(onTap: () => Navigator.of(d).pop(), child: Center(child: InteractiveViewer(child: Image.asset(url, fit: BoxFit.contain))))),
        SafeArea(child: Align(alignment: AlignmentDirectional.topEnd, child: AQIconButton(icon: 'close', directional: false, color: Colors.white, semanticsLabel: FlowStrings.of(context).t('flt.close'), onPressed: () => Navigator.of(d).pop()))),
      ]),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final b = business;
    final cats = b.categories.map((k) => f.t('bcat.${k.name}')).toList();
    final cover = b.galleryUrls.isNotEmpty ? b.galleryUrls.first : null;
    final props = ref.watch(aqAllPropertiesProvider).valueOrNull?.where((p) => p.listedByBusinessId == b.id).toList() ?? const [];
    return AQViewingScaffold(
      maxWidth: aqListMaxWidth(context) == null ? null : aqListMaxWidth(context)! + AQSpacing.gutter * 2,
      backLabel: f.t('common.back'),
      onBack: onBack,
      children: [
        // Cover photograph with the business mark overlapping its lower edge.
        Stack(
          clipBehavior: Clip.none,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AQRadius.large),
              child: AspectRatio(
                aspectRatio: MediaQuery.sizeOf(context).width >= 700 ? 2.2 : 16 / 10,
                child: ExcludeSemantics(child: cover == null ? ColoredBox(color: c.surfaceSelected) : aqImg(cover, cacheWidth: 1000)),
              ),
            ),
            PositionedDirectional(start: AQSpacing.x4, bottom: -32, child: DecoratedBox(decoration: BoxDecoration(borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.background, width: 3)), child: AQThumb(monogramOf: b.name, size: 64))),
          ],
        ),
        const SizedBox(height: AQSpacing.x10),
        Semantics(header: true, child: Text(VFmt.iso(b.name), style: AQTypography.of(context, AQText.headlineLarge))),
        const SizedBox(height: AQSpacing.x1),
        Text(cats.join(' · '), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x3),
        Wrap(spacing: AQSpacing.x4, runSpacing: AQSpacing.x2, children: [
          if (b.verification.isVerified)
            Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('verified', size: 18, color: c.accent), const SizedBox(width: 6), Flexible(child: Text(f.t('bp.verifiedBusiness'), style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep)))]),
          if (b.rating != null)
            Row(mainAxisSize: MainAxisSize.min, children: [AQIcon('star-fill', size: 16, color: c.warning), const SizedBox(width: 6), Flexible(child: Text('${b.rating!.toStringAsFixed(1)} · ${f.t('pro.reviews', {'n': VFmt.n(context, b.reviewCount ?? 0)})}', style: AQTypography.of(context, AQText.labelMedium)))]),
        ]),
        const SizedBox(height: AQSpacing.x4),
        _info(context, 'pin', b.locationLabel),
        if (b.serviceArea.isNotEmpty) _info(context, 'globe', f.t('bp.serves', {'area': b.serviceArea})),
        if (_engagementType(b) != null) ...[
          const SizedBox(height: AQSpacing.x3),
          AQSecondaryButton(label: f.t('ce.engage.cta'), leadingIcon: 'verified', trailingChevron: false, onPressed: () => context.push('/business/${b.id}/engage?name=${Uri.encodeComponent(b.name)}&type=${_engagementType(b)}')),
        ],
        if (b.categories.contains(BusinessCategory.maintenance)) ...[
          const SizedBox(height: AQSpacing.x3),
          AQPrimaryButton(label: f.t('mnt.book.cta'), leadingIcon: 'calendar', trailingChevron: false, onPressed: () => context.push('/business/${b.id}/book')),
        ],
        const SizedBox(height: AQSpacing.x3),
        AQContactButtons(name: b.name, phone: aqDemoPhoneFor(b.id)),
        _head(context, f.t('bp.about')),
        Text(b.description.isEmpty ? f.t('bp.noDesc') : b.description, style: AQTypography.of(context, AQText.bodyMedium)),
        _head(context, f.t('bp.services')),
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
          for (final k in cats) Container(constraints: const BoxConstraints(minHeight: 40), padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4), decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.hairline)), child: Center(widthFactor: 1, child: Text(k, style: AQTypography.of(context, AQText.labelMedium, color: c.inkSoft)))),
        ]),
        _head(context, f.t('bp.portfolio')),
        if (b.galleryUrls.isEmpty)
          Text(f.t('bp.noPortfolio'), style: AQTypography.of(context, AQText.bodyMedium, soft: true))
        else
          LayoutBuilder(builder: (context, box) {
            // The first project photograph runs the full width; the rest sit two across (three on wide screens).
            const gap = AQSpacing.x3;
            final cols2 = box.maxWidth >= 560 ? 3 : 2;
            final w = (box.maxWidth - gap * (cols2 - 1)) / cols2;
            Widget tile(int i, double width, double height) => SizedBox(
                  width: width,
                  height: height,
                  child: Semantics(
                    button: true,
                    focusable: true,
                    onFocus: () {},
                    label: f.t('bp.photo', {'i': VFmt.n(context, i + 1), 'n': VFmt.n(context, b.galleryUrls.length)}),
                    excludeSemantics: true,
                    onTap: () => _photo(context, b.galleryUrls[i]),
                    child: AQPressable(onTap: () => _photo(context, b.galleryUrls[i]), child: ClipRRect(borderRadius: BorderRadius.circular(AQRadius.medium), child: aqImg(b.galleryUrls[i], cacheWidth: i == 0 ? 900 : 560))),
                  ),
                );
            return Wrap(spacing: gap, runSpacing: gap, children: [
              tile(0, box.maxWidth, box.maxWidth / 1.7),
              for (var i = 1; i < b.galleryUrls.length; i++) tile(i, w, w * 0.8),
            ]);
          }),
        if (props.isNotEmpty) ...[
          _head(context, f.t('bp.listings')),
          for (final p in props) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: AQResultCard(property: p)),
        ],
        _head(context, f.t('bp.reviews'), trailing: AQTextButton(label: f.t('bp.write'), color: c.accentDeep, onPressed: () => context.push('/review/${b.categories.contains(BusinessCategory.maintenance) ? 'provider' : 'professional'}/${b.id}?name=${Uri.encodeComponent(b.name)}'))),
        Text(b.rating == null ? f.t('bp.noReviews') : f.t('bp.ratedBy', {'r': b.rating!.toStringAsFixed(1), 'n': VFmt.n(context, b.reviewCount ?? 0)}), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x4),
      ],
    );
  }
}

/// The professional type key an engagement is requested under, or null when this business is not a
/// professional (agents and maintenance providers use other flows).
String? _engagementType(Business b) {
  for (final c in b.categories) {
    switch (c) {
      case BusinessCategory.construction:
        return 'construction';
      case BusinessCategory.propertyDevelopment:
        return 'development';
      case BusinessCategory.architecture:
        return 'architecture';
      case BusinessCategory.interiorDesign:
      case BusinessCategory.exteriorDesign:
        return 'interior_exterior';
      default:
        break;
    }
  }
  return null;
}
