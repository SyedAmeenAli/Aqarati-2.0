import '../../core/aq/aq_glass.dart';
import '../media/aq_media.dart';
import '../account/profile_photo.dart';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/enums.dart';
import '../../core/aq/aq_help.dart';
import '../ads/sponsored_banner.dart';
import 'aq_cards.dart' show AQCompactPropertyCard, AQPropertyCard, AQResultGrid, aqListMaxWidth;
import 'aq_home_sections.dart';
import 'aq_home_services.dart';
import '../../data/models/property.dart';
import '../../data/repositories/app_state_providers.dart'
    show savedPropertyIdsProvider;
import '../../data/repositories/providers.dart';
import '../entry/widgets/entry_common.dart' show MasterLogo;
import '../search/aq_filter_sheet.dart';
import '../search/aq_filters.dart';
import '../search/aq_map.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';

export '../search/aq_filters.dart' show PropCategory, PropCategoryX;

// ---------------------------------------------------------------- state

/// null = all of Oman.
final homeAreaProvider = StateProvider<String?>((ref) => null);
final homeTxProvider = StateProvider<TransactionType>(
  (ref) => TransactionType.buy,
);
final savedPropertiesProvider = savedPropertyIdsProvider;
final aqAllPropertiesProvider = FutureProvider.autoDispose<List<Property>>(
  (ref) => ref.watch(propertyRepositoryProvider).search(),
);

// ---------------------------------------------------------------- shared pieces

Widget aqImg(
  String asset, {
  int cacheWidth = 500,
  Alignment alignment = Alignment.center,
}) => asset.startsWith('memory:') && aqMemoryMedia[asset] != null
    ? AqMediaView(image: aqMemoryMedia[asset]!, kind: AqMediaKind.portfolio)
    : Image.asset(
  asset,
  fit: BoxFit.cover,
  alignment: alignment,
  cacheWidth: cacheWidth,
  filterQuality: FilterQuality.medium,
  // Photographs ease in once decoded instead of popping; reduced motion shows them at once.
  frameBuilder: (context, child, frame, sync) => sync || AQMotion.reduced(context)
      ? child
      : AnimatedOpacity(opacity: frame == null ? 0 : 1, duration: AQMotion.scaled(context, AQMotion.slow), curve: Curves.easeOut, child: child),
  errorBuilder: (_, _, _) => const ColoredBox(color: Color(0x22000000)),
);

/// Top of Home / Explore: a photograph that fades into the page, brand row, title, search.
class AQHero extends StatelessWidget {
  final String image;
  final String? eyebrow;
  final String title;
  final String sub;
  final VoidCallback? onBack;

  /// The property-area chip is a Home/Explore preference; pages it does not filter hide it.
  final bool showLocation;

  /// Optional block between the header row and the greeting (Home: the sponsored banner).
  final Widget? belowHeader;
  const AQHero({
    super.key,
    required this.image,
    this.eyebrow,
    required this.title,
    required this.sub,
    this.onBack,
    this.showLocation = true,
    this.belowHeader,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final bg = c.background;
    return Stack(
      children: [
        Positioned.fill(
          child: ExcludeSemantics(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: c.isDark ? 0.75 : 1,
                  child: aqImg(
                    image,
                    cacheWidth: 1000,
                    alignment: Alignment.topCenter,
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        bg.withValues(alpha: 0.94),
                        bg.withValues(alpha: 0.6),
                        bg.withValues(alpha: 0.05),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        bg.withValues(alpha: 0),
                        bg.withValues(alpha: 0),
                        bg,
                      ],
                      stops: const [0, 0.62, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AQSpacing.gutter,
              AQSpacing.x2,
              AQSpacing.gutter,
              AQSpacing.x6,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (onBack != null)
                      AQIconButton(
                        icon: 'chevron-left',
                        semanticsLabel: f.t('common.back'),
                        onPressed: onBack,
                      )
                    else
                      SizedBox(
                        height: 46,
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: MasterLogo(width: 80),
                        ),
                      ),
                    const Spacer(),
                    if (showLocation) ...[
                      const AQLocationPill(),
                      const SizedBox(width: AQSpacing.x2),
                    ],
                    Semantics(
                      button: true,
                      focusable: true,
                      onFocus: () {},
                      label: f.t('nav.account'),
                      excludeSemantics: true,
      onTap: () => context.go('/app/account'),
                      child: AQPressable(
                        onTap: () => context.go('/app/account'),
                        child: const AQAvatar(size: 44),
                      ),
                    ),
                  ],
                ),
                ?belowHeader,
                const SizedBox(height: AQSpacing.x5),
                if (eyebrow != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AQSpacing.x1),
                    child: Text(
                      eyebrow!,
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        color: c.accentDeep,
                      ),
                    ),
                  ),
                Semantics(
                  header: true,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 330),
                    child: Text(
                      title,
                      style: AQTypography.of(context, AQText.displaySmall),
                    ),
                  ),
                ),
                if (sub.isNotEmpty) ...[
                  const SizedBox(height: AQSpacing.x2),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: Text(
                      sub,
                      style: AQTypography.of(context, AQText.bodyMedium),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class AQLocationPill extends ConsumerWidget {
  const AQLocationPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final area = ref.watch(homeAreaProvider);
    final label = area ?? f.t('home.loc.all');
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${f.t('home.loc.title')}: $label',
      excludeSemantics: true,
      onTap: () => _pickArea(context, ref),
      child: AQPressable(
        onTap: () => _pickArea(context, ref),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AQControl.tap, maxWidth: 170),
          child: AQGlass(
          radius: 22,
          blur: 14,
          fill: 0.7,
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: 11),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AQIcon('pin', size: 16, color: c.accent),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(context, AQText.labelMedium),
                ),
              ),
              const SizedBox(width: 4),
              AQIcon('chevron-down', size: 16, color: c.inkSoft),
            ],
          ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pickArea(BuildContext context, WidgetRef ref) async {
  final f = FlowStrings.of(context);
  final all = await ref.read(propertyRepositoryProvider).search();
  final areas = {for (final p in all) p.area}.toList()..sort();
  if (!context.mounted) return;
  await showAQSheet<void>(
    context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AQSpacing.gutter,
            AQSpacing.x2,
            AQSpacing.gutter,
            AQSpacing.x2,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              f.t('home.loc.title'),
              style: AQTypography.of(sheet, AQText.headlineSmall),
            ),
          ),
        ),
        AQSheetRow(
          title: f.t('home.loc.all'),
          selected: ref.read(homeAreaProvider) == null,
          onTap: () {
            ref.read(homeAreaProvider.notifier).state = null;
            Navigator.of(sheet).pop();
          },
        ),
        for (final a in areas)
          AQSheetRow(
            title: a,
            selected: ref.read(homeAreaProvider) == a,
            onTap: () {
              ref.read(homeAreaProvider.notifier).state = a;
              Navigator.of(sheet).pop();
            },
          ),
      ],
    ),
  );
}

class AQSearchEntry extends StatelessWidget {
  final String hint;
  const AQSearchEntry({super.key, required this.hint});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: hint,
      excludeSemantics: true,
      onTap: () => context.go('/app/explore?focus=1'),
      child: AQPressable(
        onTap: () => context.go('/app/explore?focus=1'),
        // A field-shaped row, not a Material input: a raised pill with a hairline and a soft lift, the
        // search glyph first and a small accent disc (filters) at the end. The whole row opens search.
        child: Container(
          constraints: const BoxConstraints(minHeight: AQControl.field),
          padding: const EdgeInsetsDirectional.only(start: AQSpacing.x5, end: AQSpacing.x2, top: AQSpacing.x2, bottom: AQSpacing.x2),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQControl.field),
            border: Border.all(color: c.hairline),
            boxShadow: AQElevation.floating,
          ),
          child: Row(
            children: [
              AQIcon('search', size: 22, color: c.accentDeep),
              const SizedBox(width: AQSpacing.x3),
              Expanded(
                child: Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    color: c.inkSoft,
                  ),
                ),
              ),
              const SizedBox(width: AQSpacing.x2),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle),
                child: Center(child: AQIcon('sliders', size: 18, color: c.onAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AQSectionHeader extends StatelessWidget {
  final String title;
  final String? sub;
  final String? action;
  final VoidCallback? onAction;

  /// Shows the question-mark real-estate explainer beside the title.
  final bool help;
  const AQSectionHeader(
    this.title, {
    this.sub,
    this.action,
    this.onAction,
    this.help = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AQTypography.of(context, AQText.headlineMedium),
                ),
              ),
            ),
            if (help) const AQHelpButton(),
          ],
        ),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              sub!,
              style: AQTypography.of(context, AQText.bodySmall, soft: true),
            ),
          ),
      ],
    );
    final button = action == null
        ? null
        : AQTextButton(
            label: action!,
            color: c.accentDeep,
            trailingIcon: 'chevron-right',
            onPressed: onAction,
          );
    // At very large text the action moves under the heading instead of squeezing it.
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.4;
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
      child: stacked && button != null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                heading,
                Align(alignment: AlignmentDirectional.centerEnd, child: button),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                ?button,
              ],
            ),
    );
  }
}


/// Wide photographic banner with a title, line of copy and one pill action.
class AQBanner extends StatelessWidget {
  final String image;

  /// A creative held in memory (admin previews). Takes precedence over [image].
  final Uint8List? imageBytes;
  final String eyebrow, title, body, cta;
  final VoidCallback onTap;
  const AQBanner({
    super.key,
    required this.image,
    this.imageBytes,
    this.eyebrow = '',
    required this.title,
    required this.body,
    required this.cta,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AQRadius.medium),
      child: Stack(
        children: [
          Positioned.fill(
            child: ExcludeSemantics(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageBytes != null)
                    Image.memory(
                      imageBytes!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0x22000000)),
                    )
                  else if (image.startsWith('https://'))
                    Image.network(
                      image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const ColoredBox(color: Color(0x22000000)),
                    )
                  else
                    aqImg(image, cacheWidth: 900),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: AlignmentDirectional.centerStart,
                        end: AlignmentDirectional.centerEnd,
                        colors: [
                          c.background.withValues(alpha: 0.95),
                          c.background.withValues(alpha: 0.7),
                          c.background.withValues(alpha: 0.0),
                        ],
                        stops: const [0, 0.5, 1],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AQSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow.isNotEmpty)
                  Text(
                    eyebrow,
                    style: AQTypography.of(
                      context,
                      AQText.labelSmall,
                      color: c.accentDeep,
                    ),
                  ),
                Text(
                  title,
                  style: AQTypography.of(context, AQText.headlineMedium),
                ),
                const SizedBox(height: AQSpacing.x1),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 210),
                  child: Text(
                    body,
                    style: AQTypography.of(context, AQText.bodySmall),
                  ),
                ),
                const SizedBox(height: AQSpacing.x4),
                Semantics(
                  button: true,
                  focusable: true,
                  onFocus: () {},
                  label: cta,
                  excludeSemantics: true,
      onTap: onTap,
                  child: AQPressable(
                    onTap: onTap,
                    child: Container(
                      constraints: const BoxConstraints(
                        minHeight: AQControl.tap - 4,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AQSpacing.x4,
                      ),
                      decoration: BoxDecoration(
                        color: c.accent,
                        borderRadius: BorderRadius.circular(AQControl.tap),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              cta,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AQTypography.of(
                                context,
                                AQText.labelMedium,
                                color: c.onAccent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          AQIcon(
                            'chevron-right',
                            size: 16,
                            color: c.onAccent,
                            directional: true,
                          ),
                        ],
                      ),
                    ),
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

class _Dots extends StatelessWidget {
  final int count, index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.fast),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == index ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: i == index ? c.accent : c.hairline,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
        ],
      ),
    );
  }
}

class AQSlideSwitch extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const AQSlideSwitch({
    super.key,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AQControl.tap),
        border: Border.all(color: c.hairline),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: AQMotion.scaled(context, AQMotion.standard),
              curve: AQMotion.spring,
              alignment: AlignmentDirectional(
                labels.length == 1 ? 0 : -1 + 2 * index / (labels.length - 1),
                0,
              ),
              child: FractionallySizedBox(
                widthFactor: 1 / labels.length,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(AQControl.tap),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    focusable: true,
                    onFocus: () {},
                    selected: i == index,
                    label: labels[i],
                    excludeSemantics: true,
                    onTap: () {
                      AQHaptics.selection();
                      onChanged(i);
                    },
                    child: AQPressable(
                      onTap: () {
                        AQHaptics.selection();
                        onChanged(i);
                      },
                      pressedScale: 0.97,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: AQControl.tap - 4,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          labels[i],
                          style: AQTypography.of(
                            context,
                            AQText.labelMedium,
                            color: i == index ? c.onAccent : c.inkSoft,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- featured carousel

class _Featured extends ConsumerStatefulWidget {
  final List<Property> items;
  const _Featured({required this.items});
  @override
  ConsumerState<_Featured> createState() => _FeaturedState();
}

class _FeaturedState extends ConsumerState<_Featured> {
  final _ctl = PageController(viewportFraction: 0.94);
  int _i = 0;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final saved = ref.watch(savedPropertiesProvider);
    final h = aqLargeText(context) ? 400.0 : 320.0;
    return Column(
      children: [
        SizedBox(
          height: h,
          child: PageView.builder(
            controller: _ctl,
            itemCount: widget.items.length,
            onPageChanged: (i) => setState(() => _i = i),
            itemBuilder: (context, i) {
              final p = widget.items[i];
              final isSaved = saved.contains(p.id);
              final facts = [
                if (p.bedrooms != null)
                  '${VFmt.n(context, p.bedrooms!)} ${f.t('disc.beds')}',
                if (p.bathrooms != null)
                  '${VFmt.n(context, p.bathrooms!)} ${f.t('home.baths')}',
                '${VFmt.n(context, p.areaSqm.round())} m²',
              ];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Semantics(
                        button: true,
                        focusable: true,
                        onFocus: () {},
                        label:
                            '${p.title}, ${p.locationLabel}, ${p.priceLabel}',
                        excludeSemantics: true,
      onTap: () => context.push('/property/${p.id}'),
                        child: AQPressable(
                          onTap: () => context.push('/property/${p.id}'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AQRadius.large),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                p.imageUrls.isEmpty
                                    ? const ColoredBox(color: Color(0x33000000))
                                    : aqImg(
                                        p.imageUrls.first,
                                        cacheWidth: 1000,
                                      ),
                                const DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0x00000000),
                                        Color(0x00000000),
                                        Color(0xCC1A1613),
                                      ],
                                      stops: [0, 0.4, 1],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: AQSpacing.x4,
                                  top: AQSpacing.x4,
                                  child: _Badge(f.t('home.featuredBadge')),
                                ),
                                Positioned(
                                  left: AQSpacing.x4,
                                  right: AQSpacing.x4,
                                  bottom: AQSpacing.x4,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              VFmt.iso(p.title),
                                              style: AQTypography.of(
                                                context,
                                                AQText.headlineMedium,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                const AQIcon(
                                                  'pin',
                                                  size: 14,
                                                  color: Color(0xFFEBDDCB),
                                                ),
                                                const SizedBox(width: 4),
                                                Flexible(
                                                  child: Text(
                                                    VFmt.iso(
                                                      p.locationLabel
                                                          .split(',')
                                                          .take(2)
                                                          .join(',')
                                                          .trim(),
                                                    ),
                                                    style: AQTypography.of(
                                                      context,
                                                      AQText.bodySmall,
                                                      color: const Color(
                                                        0xFFEBDDCB,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(
                                              height: AQSpacing.x1,
                                            ),
                                            Text(
                                              p.priceLabel,
                                              style: AQTypography.of(
                                                context,
                                                AQText.titleLarge,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              facts.join('  ·  '),
                                              style: AQTypography.of(
                                                context,
                                                AQText.bodySmall,
                                                color: const Color(0xFFEBDDCB),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: AQSpacing.x3),
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: AQColors.light.accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: AQIcon(
                                            'chevron-right',
                                            size: 22,
                                            color: Colors.white,
                                            directional: true,
                                          ),
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
                    ),
                    PositionedDirectional(
                      end: AQSpacing.x3,
                      top: AQSpacing.x3,
                      child: Semantics(
                        button: true,
                        focusable: true,
                        onFocus: () {},
                        selected: isSaved,
                        label: isSaved ? f.t('home.unsave') : f.t('home.save'),
                        excludeSemantics: true,
      onTap: () {
                            AQHaptics.confirm();
                            final next = {...saved};
                            isSaved ? next.remove(p.id) : next.add(p.id);
                            ref.read(savedPropertiesProvider.notifier).state =
                                next;
                          },
                        child: AQPressable(
                          onTap: () {
                            AQHaptics.confirm();
                            final next = {...saved};
                            isSaved ? next.remove(p.id) : next.add(p.id);
                            ref.read(savedPropertiesProvider.notifier).state =
                                next;
                          },
                          pressedScale: 0.9,
                          child: Container(
                            width: 48,
                            height: 48,
                            alignment: Alignment.center,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0x66000000),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: AQHeart(
                                  saved: isSaved,
                                  savedColor: const Color(0xFFE08A78),
                                  idleColor: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        if (widget.items.length > 1)
          _Dots(count: widget.items.length, index: _i),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xAA2D2823),
      borderRadius: BorderRadius.circular(AQRadius.small),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AQSpacing.x3,
        vertical: 6,
      ),
      child: Text(
        text,
        style: AQTypography.of(
          context,
          AQText.labelSmall,
          color: const Color(0xFFF1E8DB),
        ),
      ),
    ),
  );
}


Widget aqPage(
  BuildContext context, {
  required Widget hero,
  required List<Widget> children,
}) {
  return SingleChildScrollView(
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width >= 1000 ? 960 : (MediaQuery.sizeOf(context).width >= 700 ? 760 : AQSpacing.maxContent + AQSpacing.gutter * 2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            hero,
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AQSpacing.gutter,
                0,
                AQSpacing.gutter,
                128,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------- Home

/// The six modules of User to Shop, in the approved order. One entry point to each; the
/// sections below stay as they were.
/// The four primary property actions, first thing under the greeting: Buy, Rent, Sell with
/// Aqary e-Broker and My Favorites. Each goes straight to its own journey.
class AQHomeScreen extends ConsumerWidget {
  /// Optional first block under the header: the status banner for an application that is not approved yet.
  final Widget? topSlot;

  /// Optional compact control under the header (the Shop / Work mode capsule of an approved agent).
  final Widget? modeSwitch;
  const AQHomeScreen({super.key, this.topSlot, this.modeSwitch});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    // Shop Home has three things, in this order: the search bar, the sponsored banner and the six services.
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width >= 720 ? 880 : AQSpacing.maxContent + AQSpacing.gutter * 2,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x1, AQSpacing.gutter, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AQHomeHeader(),
                  if (modeSwitch != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AQSpacing.x1),
                      child: Align(alignment: AlignmentDirectional.centerEnd, child: modeSwitch),
                    ),
                  ?topSlot,
                  const SizedBox(height: AQSpacing.x3),
                  AQSearchEntry(hint: f.t('home.search.hint')),
                  const SizedBox(height: AQSpacing.x5),
                  const SponsoredBannerSlot(),
                  const SizedBox(height: AQSpacing.x4),
                  const AQHomeServices(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AQSkeletonBox extends StatelessWidget {
  final double height;
  const AQSkeletonBox({super.key, required this.height});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: c.ink.withValues(alpha: c.isDark ? 0.08 : 0.05),
          borderRadius: BorderRadius.circular(AQRadius.large),
        ),
      ),
    );
  }
}

class AQNoticeLine extends StatelessWidget {
  final String text;
  const AQNoticeLine({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AQSpacing.x6),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: AQTypography.of(context, AQText.bodyMedium, soft: true),
    ),
  );
}

// ---------------------------------------------------------------- Explore


// ---------------------------------------------------------------- Properties browse

class AQPropertiesScreen extends ConsumerStatefulWidget {
  final String? category;
  final String? tx;
  final String? types;
  const AQPropertiesScreen({super.key, this.category, this.tx, this.types});
  @override
  ConsumerState<AQPropertiesScreen> createState() => _AQPropertiesScreenState();
}

class _AQPropertiesScreenState extends ConsumerState<AQPropertiesScreen> {
  late final AQFilters _f = AQFilters(
    category: PropCategory.values
        .where((c) => c.name == widget.category)
        .firstOrNull,
    types: {
      for (final n in (widget.types ?? '').split(','))
        ...PropertyType.values.where((t) => t.name == n),
    },
    tx: switch (widget.tx) {
      'buy' => TransactionType.buy,
      'rent' => TransactionType.rent,
      _ => null,
    },
  );

  @override
  void initState() {
    super.initState();
    final area = ref.read(homeAreaProvider);
    if (area != null) _f.areas.add(area);
  }

  Future<void> _openFilters(List<Property> all) async {
    final next = await showAQFilterSheet(context, all: all, initial: _f);
    if (next == null || !mounted) return;
    setState(() {
      _f.tx = next.tx;
      _f.category = next.category;
      _f.types
        ..clear()
        ..addAll(next.types);
      _f.areas
        ..clear()
        ..addAll(next.areas);
      _f.amenities
        ..clear()
        ..addAll(next.amenities);
      _f.minPrice = next.minPrice;
      _f.maxPrice = next.maxPrice;
      _f.beds = next.beds;
      _f.baths = next.baths;
      _f.minArea = next.minArea;
      _f.verifiedOnly = next.verifiedOnly;
    });
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    // The location pill in the corner drives the same area filter.
    ref.listen<String?>(
      homeAreaProvider,
      (_, area) => setState(() {
        _f.areas.clear();
        if (area != null) _f.areas.add(area);
      }),
    );
    final async = ref.watch(aqAllPropertiesProvider);
    final txIndex = _f.tx == null ? 0 : (_f.tx == TransactionType.buy ? 1 : 2);
    return AQViewingScaffold(
      maxWidth: aqListMaxWidth(context) == null ? null : aqListMaxWidth(context)! + AQSpacing.gutter * 2,
      title: f.t('props.title'),
      subtitle: f.t('props.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/explore'),
      trailing: AQViewToggle(
        map: false,
        onList: () {},
        onMap: () =>
            context.push('/map${_f.tx == null ? '' : '?tx=${_f.tx!.name}'}'),
      ),
      children: [
        AQSearchEntry(hint: f.t('props.search')),
        const SizedBox(height: AQSpacing.x4),
        // One scrolling line of categories (a two-row cloud pushed the first listing below the fold).
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              AQChoicePill(
                label: f.t('disc.all'),
                selected: _f.category == null,
                onTap: () => setState(() => _f.category = null),
              ),
              for (final k in PropCategory.values) ...[
                const SizedBox(width: AQSpacing.x2),
                AQChoicePill(
                  label: f.t(k.key),
                  selected: _f.category == k,
                  onTap: () => setState(() => _f.category = k),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AQSpacing.x3),
        AQSlideSwitch(
          labels: [f.t('disc.all'), f.t('home.buy'), f.t('home.rent')],
          index: txIndex,
          onChanged: (i) => setState(
            () => _f.tx = i == 0
                ? null
                : (i == 1 ? TransactionType.buy : TransactionType.rent),
          ),
        ),
        const SizedBox(height: AQSpacing.x4),
        async.when(
          loading: () => const Column(
            children: [
              AQSkeletonBox(height: 150),
              SizedBox(height: AQSpacing.x3),
              AQSkeletonBox(height: 150),
            ],
          ),
          error: (_, _) => AQErrorBanner(
            text: f.t('disc.loadError'),
            action: AQTextButton(
              label: f.t('common.retry'),
              color: c.accent,
              onPressed: () => ref.invalidate(aqAllPropertiesProvider),
            ),
          ),
          data: (all) {
            final shown = _f.apply(all);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: AQSpacing.x3),
                  child: AQResultsBar(
                    count: shown.length,
                    activeFilters: _f.activeCount,
                    onFilters: () => _openFilters(all),
                    onSort: () =>
                        showAQSortSheet(context, _f, () => setState(() {})),
                  ),
                ),
                if (shown.isEmpty)
                  Column(
                    children: [
                      AQNoticeLine(text: f.t('props.empty')),
                      if (_f.activeCount > 0 || _f.tx != null)
                        AQSecondaryButton(
                          label: f.t('flt.clear'),
                          trailingChevron: false,
                          onPressed: () => setState(_f.reset),
                        ),
                    ],
                  )
                else
                  AQResultGrid(children: [for (final p in shown) AQResultCard(property: p)]),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// A property in any list (results, saved, search hits, broker and business lists). The same card as the
/// Home rails, minus the Enquire action (lists never had one): photograph, price, name, place and facts,
/// with Save at the start of the photograph so a compare mark can sit at the end.
class AQResultCard extends StatelessWidget {
  final Property property;

  /// Kept for callers that overlay a mark at the trailing edge; the card now keeps that corner free on its own.
  final double trailingInset;

  /// A short horizontal card for fixed-height places (the map strip).
  final bool compact;
  const AQResultCard({super.key, required this.property, this.trailingInset = 0, this.compact = false});

  @override
  Widget build(BuildContext context) => compact ? AQCompactPropertyCard(property: property) : AQPropertyCard(property: property, showEnquire: false, saveAtStart: true, tagAtBottom: true);
}
