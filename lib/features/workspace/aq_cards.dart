import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../enquiry/enquiry_screen.dart';
import '../property/property_detail_screen.dart' show aqRequireSession;
import '../viewing/widgets/viewing_format.dart';
import 'aq_home.dart' show aqImg, savedPropertiesProvider;
import 'aq_thumb.dart';

/// The round save / unsave control that sits on a photograph. 48 pt target, 38 pt disc.
class AQSaveButton extends ConsumerWidget {
  final Property property;
  const AQSaveButton({super.key, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final saved = ref.watch(savedPropertiesProvider).contains(property.id);
    void toggle() {
      AQHaptics.confirm();
      final cur = ref.read(savedPropertiesProvider);
      ref.read(savedPropertiesProvider.notifier).state = saved ? ({...cur}..remove(property.id)) : {...cur, property.id};
    }

    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      selected: saved,
      label: saved ? f.t('home.unsave') : f.t('home.save'),
      excludeSemantics: true,
      onTap: toggle,
      child: AQPressable(
        onTap: toggle,
        pressedScale: 0.9,
        child: SizedBox(
          width: AQControl.tap,
          height: AQControl.tap,
          child: Center(
            child: AQGlass(
              radius: 19,
              blur: 0,
              opaque: true,
              shadow: false,
              child: SizedBox(
                width: 38,
                height: 38,
                child: Center(
                  child: AQHeart(
                    saved: saved,
                    size: 20,
                    savedColor: const Color(0xFFC25A47),
                    idleColor: AQColors.of(context).ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small label on a photograph (For sale, Featured). Glass over the picture, ink on it.
class AQPhotoTag extends StatelessWidget {
  final String text;
  const AQPhotoTag(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AQGlass(
      radius: 12,
      blur: 0,
      opaque: true,
      shadow: false,
      padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 6),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
    );
  }
}

String aqPropertyFacts(BuildContext context, Property p) {
  final f = FlowStrings.of(context);
  return [
    if (p.bedrooms != null) '${VFmt.n(context, p.bedrooms!)} ${f.t('disc.beds')}',
    if (p.bathrooms != null) '${VFmt.n(context, p.bathrooms!)} ${f.t('home.baths')}',
    // Figure and unit stay one left-to-right unit inside right-to-left text.
    '\u2066${VFmt.n(context, p.areaSqm.round())} m²\u2069',
  ].join('  ·  ');
}

String aqShortLocation(Property p) => VFmt.iso(p.locationLabel.split(',').take(2).join(',').trim());

/// The property card for rails and grids: photograph on top (4:3), then price, title, place, facts
/// and an Enquire action. The whole card opens the property; Save and Enquire are their own targets.
class AQPropertyCard extends ConsumerWidget {
  final Property property;
  final bool showEnquire;

  /// Save sits at the start of the photograph and the sale / rent tag at its foot (lists that overlay a mark at the end).
  final bool saveAtStart;
  final bool tagAtBottom;
  const AQPropertyCard({super.key, required this.property, this.showEnquire = true, this.saveAtStart = false, this.tagAtBottom = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final p = property;
    final tx = p.transactionType == TransactionType.buy ? f.t('disc.sale') : f.t('disc.rent');
    final facts = aqPropertyFacts(context, p);
    void open() => context.push('/property/${p.id}');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
        boxShadow: AQElevation.subtle,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AQRadius.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Semantics(
                  button: true,
                  focusable: true,
                  onFocus: () {},
                  label: '${p.title}, ${p.locationLabel}, $tx, $facts, ${p.priceLabel}',
                  excludeSemantics: true,
                  onTap: open,
                  child: AQPressable(
                    onTap: open,
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: p.imageUrls.isEmpty
                          ? ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon('home', size: 32, color: c.accent)))
                          : aqImg(p.imageUrls.first, cacheWidth: 700),
                    ),
                  ),
                ),
                PositionedDirectional(start: AQSpacing.x3, top: tagAtBottom ? null : AQSpacing.x3, bottom: tagAtBottom ? AQSpacing.x3 : null, child: IgnorePointer(child: AQPhotoTag(tx))),
                PositionedDirectional(start: saveAtStart ? AQSpacing.x1 : null, end: saveAtStart ? null : AQSpacing.x1, top: AQSpacing.x1, child: AQSaveButton(property: p)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.x4, AQSpacing.x3, AQSpacing.x4, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.priceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.headlineSmall, color: c.accentDeep)),
                  const SizedBox(height: 2),
                  Text(VFmt.iso(p.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                  const SizedBox(height: AQSpacing.x1),
                  Row(
                    children: [
                      AQIcon('pin', size: 14, color: c.accent),
                      const SizedBox(width: 4),
                      Expanded(child: Text(aqShortLocation(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                    ],
                  ),
                  const SizedBox(height: AQSpacing.x2),
                  Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                ],
              ),
            ),
            if (showEnquire)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AQSpacing.x2, end: AQSpacing.x2, top: AQSpacing.x1, bottom: AQSpacing.x1),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AQTextButton(
                    label: f.t('pd.enquire'),
                    color: c.accentDeep,
                    trailingIcon: 'chevron-right',
                    onPressed: () => aqRequireSession(
                      context,
                      ref,
                      actionKey: 'pd.a.enquire',
                      go: () => Navigator.of(context).push(AQRoute.route<void>(EnquiryScreen(property: p))),
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: AQSpacing.x3),
          ],
        ),
      ),
    );
  }
}

String aqBusinessCategoryLabel(FlowStrings f, BusinessCategory c) => f.t('hm8.cat.${c.name}');

/// A professional (developer, builder, studio) as a card: cover photograph, logo or monogram,
/// name, what they do, where, and their rating. Opens the business profile.
class AQProfessionalCard extends StatelessWidget {
  final Business business;

  /// Directory form: adds the full place, the review count and a two-line description under the name.
  final bool detailed;
  const AQProfessionalCard({super.key, required this.business, this.detailed = false});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final b = business;
    final cover = b.galleryUrls.isNotEmpty ? b.galleryUrls.first : null;
    final what = b.categories.map((k) => aqBusinessCategoryLabel(f, k)).take(2).join(' · ');
    final rating = b.rating;
    void open() => context.push('/business/${b.id}');
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: detailed
          ? '${b.name}, ${b.categories.map((k) => f.t('bcat.${k.name}')).join(' · ')}, ${b.locationLabel}${b.verification.isVerified ? ', ${f.t('disc.verified')}' : ''}${rating == null ? '' : ', ${rating.toStringAsFixed(1)} · ${f.t('pro.reviews', {'n': VFmt.n(context, b.reviewCount ?? 0)})}'}'
          : '${b.name}, $what, ${b.locationLabel}${rating == null ? '' : ', $rating'}',
      excludeSemantics: true,
      onTap: open,
      child: AQPressable(
        onTap: open,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
            boxShadow: AQElevation.subtle,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ExcludeSemantics(
                        child: cover == null
                            ? ColoredBox(color: c.surfaceSelected, child: Center(child: AQIcon('development', size: 28, color: c.accent)))
                            : aqImg(cover, cacheWidth: 600),
                      ),
                    ),
                    if (b.verification.isVerified)
                      PositionedDirectional(
                        end: AQSpacing.x3,
                        top: AQSpacing.x3,
                        child: AQGlass(
                          radius: 12,
                          blur: 0,
                          opaque: true,
                          shadow: false,
                          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2, vertical: 5),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AQIcon('verified', size: 14, color: c.accentDeep),
                              const SizedBox(width: 4),
                              Text(f.t('hm8.verified'), style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(AQSpacing.x4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      aqRowLead(AQThumb(monogramOf: b.name, size: 44)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                            const SizedBox(height: 2),
                            Text(what, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                            const SizedBox(height: AQSpacing.x1),
                            Row(
                              children: [
                                if (rating != null) ...[
                                  AQIcon('star-fill', size: 14, color: c.accent),
                                  const SizedBox(width: 4),
                                  Flexible(child: Text(detailed ? '${VFmt.dec(context, rating, digits: 1)} · ${f.t('pro.reviews', {'n': VFmt.n(context, b.reviewCount ?? 0)})}' : VFmt.dec(context, rating, digits: 1), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium))),
                                  const SizedBox(width: 6),
                                ],
                                if (!detailed) Expanded(child: Text(VFmt.iso(b.locationLabel.split(',').first.trim()), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true))),
                              ],
                            ),
                            if (detailed) ...[
                              const SizedBox(height: AQSpacing.x1),
                              Row(children: [AQIcon('pin', size: 14, color: c.accent), const SizedBox(width: 4), Expanded(child: Text(VFmt.iso(b.locationLabel), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)))]),
                              if (b.description.isNotEmpty) ...[
                                const SizedBox(height: AQSpacing.x2),
                                Text(b.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall)),
                              ],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The same property as a short horizontal card (photograph at the start, details beside it) for places
/// with a fixed height, such as the map's bottom strip. Same facts, same actions, same destination.
class AQCompactPropertyCard extends ConsumerWidget {
  final Property property;
  const AQCompactPropertyCard({super.key, required this.property});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final p = property;
    final large = aqLargeText(context);
    final photo = large ? 96.0 : 124.0;
    final tx = p.transactionType == TransactionType.buy ? f.t('disc.sale') : f.t('disc.rent');
    final facts = aqPropertyFacts(context, p);
    void open() => context.push('/property/${p.id}');
    return DecoratedBox(
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline), boxShadow: AQElevation.subtle),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AQRadius.medium),
        child: Stack(
          children: [
            Semantics(
              button: true,
              focusable: true,
              onFocus: () {},
              label: '${p.title}, ${p.locationLabel}, $tx, $facts, ${p.priceLabel}',
              excludeSemantics: true,
              onTap: open,
              child: AQPressable(
                onTap: open,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: photo,
                        child: p.imageUrls.isEmpty ? ColoredBox(color: c.surfaceSelected) : aqImg(p.imageUrls.first, cacheWidth: 400),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AQSpacing.x3, AQSpacing.x3, AQSpacing.x3, AQSpacing.x3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(tx, style: AQTypography.of(context, AQText.labelSmall, color: c.accentDeep)),
                              Text(VFmt.iso(p.title), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleSmall)),
                              Text(aqShortLocation(p), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                              Text(facts, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                              const SizedBox(height: 2),
                              Text(p.priceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            PositionedDirectional(start: 0, top: 0, child: AQSaveButton(property: p)),
          ],
        ),
      ),
    );
  }
}

/// Lays property cards out as one column on a phone, two on a tablet and three on a desktop.
class AQResultGrid extends StatelessWidget {
  final List<Widget> children;
  const AQResultGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = AQSpacing.x3;
        final cols = box.maxWidth >= 900 ? 3 : (box.maxWidth >= 560 ? 2 : 1);
        if (cols == 1) return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final w in children) Padding(padding: const EdgeInsets.only(bottom: gap), child: w)]);
        final w = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(spacing: gap, runSpacing: gap, children: [for (final c in children) SizedBox(width: w, child: c)]);
      },
    );
  }
}

/// Width of the content column for list screens: a phone column on phones, wider on tablet and desktop.
double? aqListMaxWidth(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= 1100 ? 1120 : (w >= 720 ? 760 : null);
}
