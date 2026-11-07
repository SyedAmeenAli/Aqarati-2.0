import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_glass.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_states.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/repositories/providers.dart';
import '../entry/widgets/entry_common.dart' show MasterLogo;
import '../contact/contact_actions.dart' show chatThreadsProvider;
import '../media/aq_media.dart';
import '../viewing/widgets/viewing_format.dart';
import 'aq_cards.dart';
import 'aq_home.dart' show AQLocationPill, AQSectionHeader, aqImg;

/// Width a rail card takes: most of a phone, a fixed comfortable width on tablet and desktop.
double aqRailCardWidth(double available) => (available * 0.78).clamp(240.0, 300.0).toDouble();

/// Brand row of Home: the AQARATI mark on one side, notifications and the profile on the other.
class AQHomeHeader extends ConsumerWidget {
  const AQHomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    return Row(
      children: [
        SizedBox(height: 40, child: FittedBox(fit: BoxFit.contain, child: MasterLogo(width: 80))),
        const Spacer(),
        Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          label: f.t('nav.chats'),
          excludeSemantics: true,
          onTap: () => context.push('/chats'),
          child: AQPressable(
            onTap: () => context.push('/chats'),
            pressedScale: 0.94,
            child: SizedBox(
              width: AQControl.tap,
              height: AQControl.tap,
              child: Center(
                child: Stack(clipBehavior: Clip.none, children: [
                  AQIcon('chat', size: 26, color: AQColors.of(context).accentDeep),
                  if (ref.watch(chatThreadsProvider).isNotEmpty)
                    PositionedDirectional(end: -2, top: -2, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: AQColors.of(context).danger, shape: BoxShape.circle, border: Border.all(color: AQColors.of(context).background, width: 1.5)))),
                ]),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          label: f.t('nav.account'),
          excludeSemantics: true,
          onTap: () => context.go('/app/account'),
          child: AQPressable(
            onTap: () => context.go('/app/account'),
            pressedScale: 0.94,
            child: const SizedBox(width: AQControl.tap, height: AQControl.tap, child: Center(child: AQAvatar(size: 40))),
          ),
        ),
      ],
    );
  }
}

/// Greeting, the area the visitor is browsing, and the line of context under it.
class AQHomeGreeting extends StatelessWidget {
  final String title, sub;
  const AQHomeGreeting({super.key, required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Align(alignment: AlignmentDirectional.centerStart, child: AQLocationPill()),
        const SizedBox(height: AQSpacing.x3),
        Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.displaySmall))),
        const SizedBox(height: AQSpacing.x1),
        Text(sub, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
      ],
    );
  }
}

/// The lead picture of Home: the first featured property, edge to edge in a large rounded frame, with
/// a glass plate carrying its price, name and place. While it loads, or if there is none, a quiet
/// photograph of Muscat takes its place so the page never has a hole.
class AQHomeHero extends ConsumerWidget {
  const AQHomeHero({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final featured = ref.watch(featuredPropertiesProvider);
    final p = featured.valueOrNull?.firstOrNull;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final large = aqLargeText(context);
    return featured.when(
      loading: () => AQLoadingBlock(height: wide ? 380 : 360, radius: AQRadius.large),
      error: (_, _) => AQErrorState(
        title: f.t('hm8.error'),
        retryLabel: f.t('common.retry'),
        onRetry: () => ref.invalidate(featuredPropertiesProvider),
      ),
      data: (_) {
        final image = p != null && p.imageUrls.isNotEmpty ? p.imageUrls.first : 'assets/location/11_Muscat_skyline_and_mountains.jpg';
        final title = p == null ? f.t('hm8.hero.title') : VFmt.iso(p.title);
        final place = p == null ? f.t('hm8.hero.sub') : aqShortLocation(p);
        void open() => p == null ? context.push('/properties') : context.push('/property/${p.id}');
        return ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.large),
          child: AspectRatio(
            aspectRatio: wide ? 2.1 : (large ? 0.74 : 0.86),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(child: aqImg(image, cacheWidth: 1100, alignment: Alignment.center)),
                const IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x33000000), Color(0x00000000), Color(0x00000000), Color(0x40000000)],
                        stops: [0, 0.25, 0.6, 1],
                      ),
                    ),
                  ),
                ),
                PositionedDirectional(start: AQSpacing.x4, top: AQSpacing.x4, child: IgnorePointer(child: AQPhotoTag(f.t('hm8.hero.eyebrow')))),
                if (p != null) PositionedDirectional(end: AQSpacing.x1, top: AQSpacing.x2, child: AQSaveButton(property: p)),
                PositionedDirectional(
                  start: AQSpacing.x3,
                  end: wide ? null : AQSpacing.x3,
                  bottom: AQSpacing.x3,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Semantics(
                      button: true,
                      focusable: true,
                      onFocus: () {},
                      label: p == null ? '$title. $place' : '$title, $place, ${p.priceLabel}',
                      excludeSemantics: true,
                      onTap: open,
                      child: AQPressable(
                        onTap: open,
                        child: AQGlass(
                          radius: 22,
                          blur: 18,
                          fill: 0.95,
                          opaque: true,
                          padding: const EdgeInsets.all(AQSpacing.x4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.headlineSmall)),
                                    const SizedBox(height: 2),
                                    Text(place, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                                    if (p != null) ...[
                                      const SizedBox(height: AQSpacing.x2),
                                      Text(p.priceLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleMedium, color: c.accentDeep)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: AQSpacing.x3),
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                                child: Center(child: AQIcon('chevron-right', size: 20, color: c.onAccent, directional: true)),
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
      },
    );
  }
}

/// A horizontally scrolling row of cards that runs to the screen edge while its first card lines up
/// with the page margin. Cards share a height.
class AQRail extends StatelessWidget {
  final List<Widget> children;
  final double cardWidth;
  const AQRail({super.key, required this.children, required this.cardWidth});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter, vertical: AQSpacing.x1),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: AQSpacing.x3),
              SizedBox(width: cardWidth, child: children[i]),
            ],
          ],
        ),
      ),
    );
  }
}

/// "Featured properties": the rest of the featured listings after the one in the hero.
class AQHomeFeatured extends ConsumerWidget {
  final double width;
  const AQHomeFeatured({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final featured = ref.watch(featuredPropertiesProvider);
    final items = (featured.valueOrNull ?? const []).skip(1).take(6).toList();
    if (featured.hasValue && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter),
          child: AQSectionHeader(f.t('hm8.featured'), sub: f.t('hm8.featured.s'), action: f.t('hm8.seeAll'), onAction: () => context.push('/properties')),
        ),
        if (featured.isLoading)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AQSpacing.gutter), child: AQLoadingBlock(height: 300))
        else
          AQRail(cardWidth: aqRailCardWidth(width), children: [for (final p in items) AQPropertyCard(property: p)]),
      ],
    );
  }
}

/// "Trusted professionals": verified developers, builders and designers.
class AQHomePros extends ConsumerWidget {
  final double width;
  const AQHomePros({super.key, required this.width});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final all = ref.watch(businessesProvider);
    final items = (all.valueOrNull ?? const []).where((b) => b.verification.isVerified).take(8).toList();
    if (all.hasValue && items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter),
          child: AQSectionHeader(f.t('hm8.pros'), sub: f.t('hm8.pros.s'), action: f.t('hm8.seeAll'), onAction: () => context.push('/professionals')),
        ),
        if (all.isLoading)
          const Padding(padding: EdgeInsets.symmetric(horizontal: AQSpacing.gutter), child: AQLoadingBlock(height: 220))
        else if (all.hasError)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter),
            child: AQErrorState(title: f.t('hm8.error'), retryLabel: f.t('common.retry'), onRetry: () => ref.invalidate(businessesProvider)),
          )
        else
          AQRail(cardWidth: aqRailCardWidth(width) - 20, children: [for (final b in items) AQProfessionalCard(business: b)]),
      ],
    );
  }
}
