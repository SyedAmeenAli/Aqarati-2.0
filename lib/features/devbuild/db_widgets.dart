import '../../core/domain/account_models.dart' show InteriorExteriorServiceType;
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
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_home.dart' show aqImg;
import 'db_models.dart';
import 'db_repository.dart';

/// Icons the AQ family lacks fall back to Material outlines so every control has a glyph.
class DbIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color? color;
  const DbIcon(
    this.name, {
    super.key,
    this.size = AQIconSize.medium,
    this.color,
  });

  static const _fallback = <String, IconData>{
    'plus': Icons.add_rounded,
    'edit': Icons.edit_outlined,
    'image': Icons.image_outlined,
    'filter': Icons.tune_rounded,
    'sort': Icons.swap_vert_rounded,
    'list': Icons.view_agenda_outlined,
    'map': Icons.map_outlined,
    'more': Icons.more_vert_rounded,
    'trash': Icons.delete_outline_rounded,
    'bath': Icons.bathtub_outlined,
    'doc': Icons.description_outlined,
    'whatsapp': Icons.chat_bubble_outline_rounded,
    'copy': Icons.copy_rounded,
    'bell': Icons.notifications_none_rounded,
    'chart': Icons.bar_chart_rounded,
    'work': Icons.work_outline_rounded,
    'review': Icons.rate_review_outlined,
    'handshake': Icons.handshake_outlined,
    'logout': Icons.logout_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final c = color ?? AQColors.of(context).ink;
    final m = _fallback[name];
    if (m != null)
      return ExcludeSemantics(
        child: Icon(m, size: size, color: c),
      );
    return AQIcon(name, size: size, color: c);
  }
}

/// Status that never relies on colour alone: icon plus text.
class DbStatusChip extends StatelessWidget {
  final ProjectStatus status;
  final String? rawStatus;
  const DbStatusChip({super.key, required this.status, this.rawStatus});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final (fg, icon) = switch (status) {
      ProjectStatus.approved => (c.success, 'check'),
      ProjectStatus.underReview => (c.accentDeep, 'clock'),
      ProjectStatus.draft => (c.inkSoft, 'info'),
      ProjectStatus.changesRequested => (c.danger, 'alert'),
      ProjectStatus.rejected => (c.danger, 'close'),
      ProjectStatus.unknown => (c.inkSoft, 'info'),
    };
    final label =
        status == ProjectStatus.unknown && (rawStatus ?? '').isNotEmpty
        ? rawStatus!
        : f.t(status.key);
    return Semantics(
      label: '${f.t('db.status')}: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AQSpacing.x3,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: c.isDark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DbIcon(icon, size: 14, color: fg),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: AQTypography.of(context, AQText.labelSmall, color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A quiet notice: capability gaps, demo markers, explanations.
class DbNotice extends StatelessWidget {
  final String text;
  final String icon;
  final Widget? action;
  const DbNotice(this.text, {super.key, this.icon = 'info', this.action});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AQSpacing.x4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DbIcon(icon, size: 20, color: c.accent),
          ),
          const SizedBox(width: AQSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: AQTypography.of(
                    context,
                    AQText.bodyMedium,
                    soft: true,
                  ),
                ),
                if (action != null) ...[
                  const SizedBox(height: AQSpacing.x2),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DbSkeleton extends StatelessWidget {
  final double height;
  const DbSkeleton({super.key, this.height = 120});
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

class DbSkeletonList extends StatelessWidget {
  final int count;
  final double height;
  const DbSkeletonList({super.key, this.count = 3, this.height = 130});
  @override
  Widget build(BuildContext context) => Semantics(
    label: FlowStrings.of(context).t('common.loading'),
    child: Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: DbSkeleton(height: height),
          ),
      ],
    ),
  );
}

/// Failure state with a way out. [denied] switches the copy for ownership failures.
class DbErrorCard extends StatelessWidget {
  final Object? error;
  final VoidCallback? onRetry;
  const DbErrorCard({super.key, this.error, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final denied = error is PermissionDeniedException;
    return AQErrorBanner(
      text: f.t(denied ? 'db.denied.b' : 'common.networkError'),
      action: denied || onRetry == null
          ? null
          : AQTextButton(
              label: f.t('common.retry'),
              color: c.accent,
              onPressed: onRetry,
            ),
    );
  }
}

class DbSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const DbSectionTitle(this.title, {super.key, this.action, this.onAction});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: AQTypography.of(context, AQText.headlineSmall),
              ),
            ),
          ),
          if (action != null && onAction != null)
            AQTextButton(
              label: action!,
              trailingIcon: 'chevron-right',
              color: c.accentDeep,
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

String dbTypeImage(ProType t) => switch (t) {
  ProType.developer =>
    'assets/businesses/b1/05_Contemporary_architectural_facad.jpg',
  ProType.construction =>
    'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg',
  ProType.architecture =>
    'assets/businesses/b1/08_Doubleheight_atrium_architectur.jpg',
  ProType.interiorExterior =>
    'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg',
};

String dbProLabel(FlowStrings f, DbProfessional p) {
  final base = f.t(p.type.key);
  final s = p.serviceType;
  final main = s == null ? base : '$base · ${f.t('service.${s.name}')}';
  if (p.extraTypes.isEmpty) return main;
  return '$main · ${f.t('db.also', {'s': p.extraTypes.map((t) => dbCategoryLabel(f, p, t)).join(f.ar ? '، ' : ', ')})}';
}

/// One service category of a business as the public sees it. The interior/exterior category names
/// the side (or both) the business actually offers.
String dbCategoryLabel(FlowStrings f, DbProfessional p, ProType t) {
  if (t != ProType.interiorExterior) return f.t(t.key);
  return switch (p.designService) {
    InteriorExteriorServiceType.interior => f.t('st.svc.interior'),
    InteriorExteriorServiceType.exterior => f.t('st.svc.exterior'),
    _ => f.t(t.key),
  };
}

String dbGovLabel(FlowStrings f, String gov) =>
    f.ar ? (omanGovernorateAr[gov] ?? gov) : gov;

class DbRating extends StatelessWidget {
  final double? rating;
  final int? count;
  const DbRating({super.key, this.rating, this.count});
  @override
  Widget build(BuildContext context) {
    if (rating == null) return const SizedBox.shrink();
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final text =
        '${VFmt.dec(context, rating!, digits: 1)}${count == null ? '' : ' · ${f.t('pro.reviews', {'n': VFmt.n(context, count!)})}'}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AQIcon('star-fill', size: 14, color: c.warning),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: AQTypography.of(context, AQText.labelMedium),
          ),
        ),
      ],
    );
  }
}

/// One professional in a list. Developers show their approved-project count only when the API returned it.
class DbProCard extends ConsumerWidget {
  final DbProfessional pro;
  final bool selected;
  final VoidCallback? onTap;
  const DbProCard({
    super.key,
    required this.pro,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final projects = pro.type == ProType.developer
        ? ref.watch(dbApprovedProjectsProvider(pro.id)).valueOrNull
        : null;
    final rating = pro.rating == null
        ? ''
        : ', ${VFmt.dec(context, pro.rating!, digits: 1)}';
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label:
          '${pro.name}, ${dbProLabel(f, pro)}, ${pro.locationLabel}${pro.verified ? ', ${f.t('disc.verified')}' : ''}$rating',
      excludeSemantics: true,
      onTap: onTap ?? () => context.push('/build/pro/${pro.id}'),
      child: AQPressable(
        onTap: onTap ?? () => context.push('/build/pro/${pro.id}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              border: Border.all(
                color: selected ? c.accent : c.hairline,
                width: selected ? 1.5 : 1,
              ),
              borderRadius: BorderRadius.circular(AQRadius.medium),
            ),
            // Photograph-led: the cover on top (16:9), then the name, what they do, place and rating.
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pro.cover != null)
                  AspectRatio(aspectRatio: 16 / 9, child: ExcludeSemantics(child: aqImg(pro.cover!, cacheWidth: 800))),
                Padding(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 0),
                    child: Padding(
                      padding: const EdgeInsets.all(AQSpacing.x3),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  VFmt.iso(pro.name),
                                  style: AQTypography.of(
                                    context,
                                    AQText.headlineSmall,
                                  ),
                                ),
                              ),
                              if (pro.verified) ...[
                                const SizedBox(width: 6),
                                AQIcon('verified', size: 16, color: c.accent),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dbProLabel(f, pro),
                            style: AQTypography.of(
                              context,
                              AQText.bodySmall,
                              soft: true,
                            ),
                          ),
                          const SizedBox(height: AQSpacing.x1),
                          Row(
                            children: [
                              AQIcon('pin', size: 14, color: c.accent),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  VFmt.iso(pro.locationLabel),
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodySmall,
                                    soft: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (pro.rating != null) ...[
                            const SizedBox(height: AQSpacing.x1),
                            DbRating(
                              rating: pro.rating,
                              count: pro.reviewCount,
                            ),
                          ],
                          if (projects != null && projects.isNotEmpty) ...[
                            const SizedBox(height: AQSpacing.x1),
                            Text(
                              dbProjectsCount(context, f, projects.length),
                              style: AQTypography.of(
                                context,
                                AQText.labelMedium,
                                color: c.accentDeep,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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

/// A project row. Cover imagery needs approved project media, which the contract does not
/// carry yet, so the type icon stands in rather than borrowing an unrelated photo.
class DbProjectCard extends StatelessWidget {
  final DbProject project;
  final bool showStatus;
  final VoidCallback? onTap;
  final Widget? trailing;
  const DbProjectCard({
    super.key,
    required this.project,
    this.showStatus = false,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final p = project;
    final facts = [
      f.t('ptype.${p.propertyType.name}'),
      if (p.bedrooms != null)
        '${VFmt.n(context, p.bedrooms!)} ${f.t('disc.beds')}',
      if (p.areaSqm != null)
        '${VFmt.n(context, p.areaSqm!.round())} m²'
      else if (p.landSqm != null)
        '${VFmt.n(context, p.landSqm!.round())} m²',
    ].join(' · ');
    return Semantics(
      button: onTap != null,
      label:
          '${p.name}, ${p.locationLabel.isEmpty ? '' : '${p.locationLabel}, '}$facts${showStatus ? ', ${f.t(p.status.key)}' : ''}',
      excludeSemantics: true,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.zero,
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            borderRadius: BorderRadius.circular(AQRadius.medium),
            border: Border.all(color: c.hairline),
          ),
          // A project with a cover is a photograph-led card (16:9 on top); one without keeps the compact row.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AQRadius.medium),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
            if (p.cover != null)
              AspectRatio(aspectRatio: 16 / 9, child: ExcludeSemantics(child: aqImg(p.cover!, cacheWidth: 800))),
            Padding(
              padding: const EdgeInsets.all(AQSpacing.x3),
              child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.cover == null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(AQRadius.medium),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: ColoredBox(
                    color: c.surfaceSelected,
                    child: Center(child: AQIcon('development', size: 26, color: c.accent)),
                  ),
                ),
              ),
              const SizedBox(width: AQSpacing.x3),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      VFmt.iso(p.name),
                      style: AQTypography.of(context, AQText.headlineSmall),
                    ),
                    if (p.locationLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          AQIcon('pin', size: 14, color: c.accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              VFmt.iso(p.locationLabel),
                              style: AQTypography.of(
                                context,
                                AQText.bodySmall,
                                soft: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      facts,
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                    if (showStatus) ...[
                      const SizedBox(height: AQSpacing.x2),
                      DbStatusChip(status: p.status, rawStatus: p.rawStatus),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
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

/// Generic single-choice sheet used for governorate, sort and similar pickers.
Future<T?> showDbChoiceSheet<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  T? selected,
  String? clearLabel,
}) {
  return showAQSheet<T>(
    context,
    useRootNavigator: true,
    builder: (s) {
      final c = AQColors.of(s);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(s).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AQSpacing.gutter,
                AQSpacing.x3,
                AQSpacing.gutter,
                AQSpacing.x2,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: AQTypography.of(s, AQText.headlineSmall),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(
                  AQSpacing.x3,
                  0,
                  AQSpacing.x3,
                  AQSpacing.x4,
                ),
                children: [
                  for (final o in options)
                    Semantics(
                      button: true,
                      focusable: true,
                      onFocus: () {},
                      selected: o.$1 == selected,
                      label: o.$2,
                      excludeSemantics: true,
      onTap: () => Navigator.of(s).pop(o.$1),
                      child: AQPressable(
                        onTap: () => Navigator.of(s).pop(o.$1),
                        child: Container(
                          constraints: const BoxConstraints(
                            minHeight: AQControl.tap,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AQSpacing.x3,
                            vertical: AQSpacing.x2,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  o.$2,
                                  style: AQTypography.of(s, AQText.bodyLarge),
                                ),
                              ),
                              if (o.$1 == selected)
                                AQIcon('check', size: 20, color: c.accent),
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
    },
  );
}

/// Pill row used for category and filter choices.
class DbPillRow extends StatelessWidget {
  final List<(String label, bool selected, VoidCallback onTap)> pills;

  /// One horizontally scrolling line instead of wrapping rows (category bars).
  final bool scroll;
  const DbPillRow({super.key, required this.pills, this.scroll = false});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final items = [
      for (final p in pills)
        Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          selected: p.$2,
          label: p.$1,
          excludeSemantics: true,
      onTap: () {
              AQHaptics.selection();
              p.$3();
            },
          child: AQPressable(
            onTap: () {
              AQHaptics.selection();
              p.$3();
            },
            child: AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.fast),
              constraints: const BoxConstraints(minHeight: 44),
              padding: const EdgeInsets.symmetric(
                horizontal: AQSpacing.x4,
                vertical: AQSpacing.x2,
              ),
              decoration: BoxDecoration(
                color: p.$2 ? c.accent : c.surfaceRaised,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: p.$2 ? c.accent : c.hairline),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      p.$1,
                      style: AQTypography.of(
                        context,
                        AQText.labelMedium,
                        color: p.$2 ? c.onAccent : c.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
    ];
    if (scroll) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        child: Row(
          children: [
            for (final w in items)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: AQSpacing.x2),
                child: w,
              ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: AQSpacing.x2,
      runSpacing: AQSpacing.x2,
      children: items,
    );
  }
}

/// Field label + error row for custom form controls.
class DbFieldFrame extends StatelessWidget {
  final String label;
  final bool required;
  final String? error;
  final Widget child;
  const DbFieldFrame({
    super.key,
    required this.label,
    this.required = false,
    this.error,
    required this.child,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x2),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: label),
                if (required)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(color: c.accent),
                  ),
              ],
            ),
            style: AQTypography.of(context, AQText.labelMedium),
          ),
        ),
        child,
        AQAnimatedSize(
          duration: AQMotion.scaled(context, AQMotion.fast),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AQSpacing.x1),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      f.t(error!),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        color: c.danger,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Tappable select field that opens a choice sheet.
class DbSelectField<T> extends StatelessWidget {
  final String label;
  final String? valueLabel;
  final String hint;
  final bool required;
  final String? error;
  final VoidCallback? onTap;
  const DbSelectField({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.hint,
    this.required = false,
    this.error,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return DbFieldFrame(
      label: label,
      required: required,
      error: error,
      child: Semantics(
        button: true,
        focusable: true,
        onFocus: () {},
        enabled: onTap != null,
        label: '$label, ${valueLabel ?? hint}',
        excludeSemantics: true,
      onTap: onTap,
        child: AQPressable(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AQControl.field),
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(AQRadius.medium),
              border: Border.all(color: error != null ? c.danger : c.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    valueLabel ?? hint,
                    style: AQTypography.of(
                      context,
                      AQText.bodyLarge,
                      color: valueLabel == null
                          ? c.inkFaint
                          : (onTap == null ? c.inkSoft : c.ink),
                    ),
                  ),
                ),
                AQIcon('chevron-down', size: 20, color: c.inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Property type label key helper: `ptype.*` keys exist for every [PropertyType] used by projects.
String dbTypeLabel(FlowStrings f, PropertyType t) => f.t('ptype.${t.name}');

/// Start-aligned, shrink-to-fit wrapper for badges and chips that must never overflow.
class DbFit extends StatelessWidget {
  final Widget child;
  const DbFit(this.child, {super.key});
  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: child,
    ),
  );
}

/// Prominent status block for a project: icon, label and the plain-language meaning.
class DbStatusBanner extends StatelessWidget {
  final ProjectStatus status;
  final String? rawStatus;
  const DbStatusBanner({super.key, required this.status, this.rawStatus});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final (fg, icon) = switch (status) {
      ProjectStatus.approved => (c.success, 'check'),
      ProjectStatus.underReview => (c.accentDeep, 'clock'),
      ProjectStatus.changesRequested => (c.danger, 'alert'),
      ProjectStatus.rejected => (c.danger, 'close'),
      _ => (c.inkSoft, 'info'),
    };
    final label =
        status == ProjectStatus.unknown && (rawStatus ?? '').isNotEmpty
        ? rawStatus!
        : f.t(status.key);
    return Semantics(
      container: true,
      label: '${f.t('db.status')}: $label. ${f.t(status.explainKey)}',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: c.isDark ? 0.16 : 0.09),
          borderRadius: BorderRadius.circular(AQRadius.medium),
          border: Border.all(color: fg.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              child: Center(
                child: AQIcon(
                  icon,
                  size: 20,
                  color: c.isDark ? c.background : Colors.white,
                ),
              ),
            ),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AQTypography.of(
                      context,
                      AQText.headlineSmall,
                      color: fg,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    f.t(status.explainKey),
                    style: AQTypography.of(
                      context,
                      AQText.bodySmall,
                      soft: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Read-only labels (services offered). Deliberately not tappable, and drawn differently from the pill choices.
class DbTagRow extends StatelessWidget {
  final List<String> tags;
  const DbTagRow({super.key, required this.tags});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return Wrap(
      spacing: AQSpacing.x2,
      runSpacing: AQSpacing.x2,
      children: [
        for (final t in tags)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AQSpacing.x3,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: c.surfaceSelected,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(t, style: AQTypography.of(context, AQText.labelMedium)),
          ),
      ],
    );
  }
}

/// "1 project" / "N projects".
String dbProjectsCount(BuildContext context, FlowStrings f, int n) => n == 1
    ? f.t('db.projects1')
    : f.t('db.projectsN', {'n': VFmt.n(context, n)});

/// Equal-width tabs on one track with a thumb that slides to the selected one. Used for the two or
/// three views of a page (Overview, Projects, Reviews). The content below changes with it.
class DbSegmentedTabs extends StatelessWidget {
  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;
  const DbSegmentedTabs({super.key, required this.labels, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final n = labels.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.surfaceSelected,
        borderRadius: BorderRadius.circular(AQRadius.medium),
        border: Border.all(color: c.hairline),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth / n;
          return Stack(
            children: [
              AnimatedPositionedDirectional(
                duration: AQMotion.scaled(context, AQMotion.standard),
                curve: Curves.easeOutCubic,
                start: selected * w,
                width: w,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(AQRadius.small)),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: Semantics(
                        button: true,
                        focusable: true,
                        onFocus: () {},
                        selected: i == selected,
                        label: labels[i],
                        excludeSemantics: true,
                        onTap: () => onChanged(i),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: i == selected
                              ? null
                              : () {
                                  AQHaptics.selection();
                                  onChanged(i);
                                },
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2),
                            child: AnimatedDefaultTextStyle(
                              duration: AQMotion.scaled(context, AQMotion.fast),
                              style: AQTypography.of(context, AQText.labelLarge, color: i == selected ? (c.isDark ? c.background : Colors.white) : c.inkSoft),
                              child: Text(labels[i], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
