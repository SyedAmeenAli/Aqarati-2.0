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
import '../../data/models/property.dart';
import '../../data/repositories/app_state_providers.dart';
import '../../data/repositories/app_state_providers.dart' show savedSearchesProvider;
import '../saved/saved_screen.dart' show aqSaveSearch;
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_cards.dart' show AQResultGrid, aqListMaxWidth;
import '../workspace/aq_home.dart';
import 'aq_filter_sheet.dart';
import 'aq_filters.dart';

enum _Kind { property, professional, maintenance }

/// What a search term is looking for. Only properties have a results screen here;
/// the other kinds open the professionals directory.
_Kind _kindOf(String term) {
  final s = term.toLowerCase();
  if (RegExp(r'\b(ac|plumb\w*|pool service|repair|maintenance|cleaning|paint\w*|electric\w*|kitchen)\b').hasMatch(s)) return _Kind.maintenance;
  if (RegExp(r'architect|designer|interior|contractor|developer|agent|builder|construction|engineer|broker').hasMatch(s)) return _Kind.professional;
  return _Kind.property;
}

/// (query, label key). The query is matched against listing data, which is in English.
const _popular = [
  ('Villa in Muscat', 'srch.p.villa'),
  ('Apartment for rent', 'srch.p.apartment'),
  ('Land for sale', 'srch.p.land'),
  ('Architect', 'srch.p.architect'),
  ('Interior designer', 'srch.p.interior'),
  ('AC repair', 'srch.p.ac'),
  ('Pool service', 'srch.p.pool'),
];

void _remember(WidgetRef ref, String term) {
  final t = term.trim();
  if (t.isEmpty) return;
  ref.read(recentSearchesProvider.notifier).update((s) => [t, ...s.where((x) => x.toLowerCase() != t.toLowerCase())].take(6).toList());
}

/// Directory category a non-property term points at.
String? _categoryOf(String term) {
  final s = term.toLowerCase();
  if (RegExp(r'architect').hasMatch(s)) return 'architecture';
  if (RegExp(r'interior|designer').hasMatch(s)) return 'interiorDesign';
  if (RegExp(r'\b(ac|plumb\w*|pool|repair|maintenance|cleaning|paint\w*|electric\w*|kitchen)\b').hasMatch(s)) return 'maintenance';
  if (RegExp(r'contractor|construction|builder|engineer').hasMatch(s)) return 'construction';
  if (RegExp(r'developer').hasMatch(s)) return 'propertyDevelopment';
  if (RegExp(r'agent|broker').hasMatch(s)) return 'realEstateAgent';
  return null;
}

/// Runs a term: properties open the results list, everything else the directory.
void _run(BuildContext context, WidgetRef ref, String term) {
  _remember(ref, term);
  if (_kindOf(term) == _Kind.property) {
    context.push('/search?q=${Uri.encodeQueryComponent(term.trim())}');
  } else {
    final cat = _categoryOf(term);
    // The four Development & Building categories have their own directory; brokers and maintenance stay here.
    final build = switch (cat) {
      'propertyDevelopment' => 'developer',
      'construction' => 'construction',
      'architecture' => 'architecture',
      'interiorDesign' || 'exteriorDesign' => 'interiorExterior',
      _ => null,
    };
    context.push(
      build != null
          ? '/app/explore/build/results?cat=$build'
          : cat == null
              ? '/professionals?q=${Uri.encodeQueryComponent(term.trim())}'
              : '/professionals?cat=$cat',
    );
  }
}

// ---------------------------------------------------------------- query field

class AQQueryField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String> onChanged, onSubmitted;
  const AQQueryField({required this.controller, required this.hint, this.autofocus = false, required this.onChanged, required this.onSubmitted});
  @override
  State<AQQueryField> createState() => AQQueryFieldState();
}

class AQQueryFieldState extends State<AQQueryField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _focus.addListener(_sync);
  }

  void _sync() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final focused = _focus.hasFocus;
    return AnimatedContainer(
      duration: AQMotion.scaled(context, AQMotion.fast),
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsetsDirectional.only(start: AQSpacing.x4, end: AQSpacing.x1),
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(28), boxShadow: AQElevation.floating, border: Border.all(color: focused ? c.accent : c.hairline, width: focused ? 1.5 : 1)),
      child: Row(children: [
        AQIcon('search', size: 22, color: c.ink),
        const SizedBox(width: AQSpacing.x3),
        Expanded(
          child: Semantics(
            textField: true,
            label: widget.hint,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              autofocus: widget.autofocus,
              textInputAction: TextInputAction.search,
              cursorColor: c.accent,
              style: AQTypography.of(context, AQText.bodyMedium),
              // The whole rounded field carries the focus ring (the accent border above); the app-wide input theme must not
              // add a second box around the text.
              decoration: InputDecoration.collapsed(hintText: widget.hint, hintStyle: AQTypography.of(context, AQText.bodyMedium, color: c.inkFaint)).copyWith(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hoverColor: Colors.transparent,
                fillColor: Colors.transparent,
              ),
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
            ),
          ),
        ),
        if (widget.controller.text.isNotEmpty)
          AQIconButton(
            icon: 'close',
            semanticsLabel: f.t('srch.clearField'),
            directional: false,
            onPressed: () {
              widget.controller.clear();
              widget.onChanged('');
              _focus.requestFocus();
            },
          ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- search home

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _tile(BuildContext context, {required String icon, required String title, required String body, required bool primary, required VoidCallback onTap}) {
    final c = AQColors.of(context);
    final fg = primary ? c.onAccent : c.ink;
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $body',
      excludeSemantics: true,
      onTap: () {
          AQHaptics.selection();
          onTap();
        },
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 120),
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(color: primary ? c.accent : c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: primary ? c.accent : c.hairline)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AQIcon(icon, size: 24, color: primary ? c.onAccent : c.accent),
            const SizedBox(height: AQSpacing.x2),
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(title, maxLines: 1, style: AQTypography.of(context, AQText.titleSmall, color: fg))),
            const SizedBox(height: 2),
            Text(body, maxLines: 4, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodySmall, color: primary ? c.onAccent.withValues(alpha: 0.85) : c.inkSoft)),
          ]),
        ),
      ),
    );
  }

  Widget _head(BuildContext context, String title, {String? action, VoidCallback? onAction}) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x6, bottom: AQSpacing.x3),
      child: Row(children: [
        Expanded(child: Semantics(header: true, child: Text(title, style: AQTypography.of(context, AQText.headlineMedium)))),
        if (action != null) AQTextButton(label: action, color: c.accentDeep, onPressed: onAction),
      ]),
    );
  }

  Widget _recentRow(BuildContext context, String term) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    final tag = switch (_kindOf(term)) { _Kind.property => 'srch.tag.property', _Kind.professional => 'srch.tag.professional', _Kind.maintenance => 'srch.tag.maintenance' };
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.hairline))),
      child: Row(children: [
        Expanded(
          child: Semantics(
            button: true,
            focusable: true,
            onFocus: () {},
            label: '$term, ${f.t(tag)}',
            excludeSemantics: true,
      onTap: () => _run(context, ref, term),
            child: AQPressable(
              onTap: () => _run(context, ref, term),
              pressedScale: 0.99,
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                child: Row(children: [
                  AQIcon('search', size: 20, color: c.inkSoft),
                  const SizedBox(width: AQSpacing.x3),
                  Expanded(
                    child: () {
                      final text = Text(VFmt.iso(term), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.bodyMedium));
                      final chip = Container(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x2, vertical: 3), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AQRadius.small)), child: Text(f.t(tag), maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelSmall, color: c.inkSoft)));
                      if (aqLargeText(context)) return Padding(padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [text, const SizedBox(height: 4), chip]));
                      return Row(children: [Flexible(child: text), const SizedBox(width: AQSpacing.x2), Flexible(child: chip)]);
                    }(),
                  ),
                ]),
              ),
            ),
          ),
        ),
        AQIconButton(icon: 'close', directional: false, semanticsLabel: f.t('srch.removeRecent', {'q': term}), onPressed: () => ref.read(recentSearchesProvider.notifier).update((s) => s.where((x) => x != term).toList())),
      ]),
    );
  }

  Widget _quick(BuildContext context, String image, String label, VoidCallback onTap) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: label,
      excludeSemantics: true,
      onTap: () {
          AQHaptics.selection();
          onTap();
        },
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AQRadius.medium),
          child: AspectRatio(
            aspectRatio: 0.82,
            child: Stack(fit: StackFit.expand, children: [
              ExcludeSemantics(child: aqImg(image, cacheWidth: 420)),
              const DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB3000000)], stops: [0.45, 1]))),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(AQSpacing.x2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium, color: Colors.white)),
                    const SizedBox(height: 4),
                    Container(width: 28, height: 28, decoration: BoxDecoration(color: c.accent, shape: BoxShape.circle), child: Center(child: AQIcon('chevron-right', size: 16, color: c.onAccent, directional: true))),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final recent = ref.watch(recentSearchesProvider);
    final typing = _q.trim().isNotEmpty;
    final large = aqLargeText(context);

    final header = typing
        ? SafeArea(bottom: false, child: Padding(padding: const EdgeInsets.fromLTRB(AQSpacing.x2, AQSpacing.x2, AQSpacing.x2, 0), child: Row(children: [AQIconButton(icon: 'chevron-left', semanticsLabel: f.t('common.back'), onPressed: () => aqBack(context, '/app/explore'))])))
        : AQHero(image: 'assets/location/11_Muscat_skyline_and_mountains.jpg', eyebrow: f.t('srch.eyebrow'), title: f.t('srch.title'), sub: f.t('srch.sub'), onBack: () => aqBack(context, '/app/explore'));

    final tiles = [
      _tile(context, icon: 'home', title: f.t('srch.tile.props'), body: f.t('srch.tile.props.s'), primary: true, onTap: () => context.push('/properties/all')),
      _tile(context, icon: 'agent', title: f.t('srch.tile.pros'), body: f.t('srch.tile.pros.s'), primary: false, onTap: () => context.push('/professionals')),
      _tile(context, icon: 'construction', title: f.t('srch.tile.maint'), body: f.t('srch.tile.maint.s'), primary: false, onTap: () => context.push('/professionals?cat=maintenance')),
    ];

    final List<Widget> body;
    if (typing) {
      body = [
        const SizedBox(height: AQSpacing.x4),
        Consumer(builder: (context, ref, _) {
          final async = ref.watch(aqAllPropertiesProvider);
          return async.when(
            loading: () => const AQSkeletonBox(height: 150),
            error: (_, _) => AQErrorBanner(text: f.t('disc.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqAllPropertiesProvider))),
            data: (all) {
              final hits = AQFilters().apply(all, query: _q);
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: Semantics(header: true, child: Text(f.t('srch.preview'), style: AQTypography.of(context, AQText.headlineSmall)))),
                if (hits.isEmpty)
                  AQNoticeLine(text: f.t('srch.noMatch', {'q': _q.trim()}))
                else ...[
                  for (final p in hits.take(3)) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: AQResultCard(property: p)),
                  AQPrimaryButton(label: f.t('srch.seeMatching', {'n': VFmt.n(context, hits.length)}), onPressed: () => _run(context, ref, _q)),
                ],
              ]);
            },
          );
        }),
      ];
    } else {
      body = [
        large || MediaQuery.sizeOf(context).width < 340
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x2), child: t)])
            : Padding(padding: const EdgeInsets.only(top: AQSpacing.x4), child: IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (var i = 0; i < tiles.length; i++) ...[if (i > 0) const SizedBox(width: AQSpacing.x2), Expanded(child: tiles[i])]]))),
        _head(context, f.t('srch.popular')),
        Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [for (final p in _popular) AQChoicePill(label: f.t(p.$2), selected: false, onTap: () => _run(context, ref, p.$1))]),
        if (recent.isNotEmpty) ...[
          _head(context, f.t('srch.recent'), action: f.t('srch.clearRecent'), onAction: () => ref.read(recentSearchesProvider.notifier).state = []),
          for (final t in recent) _recentRow(context, t),
        ],
        const SizedBox(height: AQSpacing.x6),
        AQBanner(image: 'assets/location/12_Nizwa_Fort_and_mountains_landscape.jpg', title: f.t('srch.explore.t'), body: f.t('srch.explore.s'), cta: f.t('srch.browse'), onTap: () => context.push('/properties/all')),
        _head(context, f.t('srch.quick')),
        large
            ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _quick(context, PropCategory.residential.image, f.t('srch.tile.props'), () => context.push('/properties/all')),
                const SizedBox(height: AQSpacing.x2),
                _quick(context, 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg', f.t('srch.tile.pros'), () => context.push('/professionals')),
                const SizedBox(height: AQSpacing.x2),
                _quick(context, 'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg', f.t('srch.tile.maint'), () => context.push('/professionals?cat=maintenance')),
              ])
            : Row(children: [
                Expanded(child: _quick(context, PropCategory.residential.image, f.t('srch.tile.props'), () => context.push('/properties/all'))),
                const SizedBox(width: AQSpacing.x2),
                Expanded(child: _quick(context, 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg', f.t('srch.tile.pros'), () => context.push('/professionals'))),
                const SizedBox(width: AQSpacing.x2),
                Expanded(child: _quick(context, 'assets/businesses/b4/05_Technician_servicing_air_conditi.jpg', f.t('srch.tile.maint'), () => context.push('/professionals?cat=maintenance'))),
              ]),
      ];
    }

    return Scaffold(
      backgroundColor: c.background,
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AQSpacing.maxContent + AQSpacing.gutter * 2),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              header,
              Padding(
                padding: EdgeInsets.fromLTRB(AQSpacing.gutter, 0, AQSpacing.gutter, 48 + AQShellInset.of(context)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  AQQueryField(controller: _ctl, hint: f.t('srch.hint'), autofocus: false, onChanged: (v) => setState(() => _q = v), onSubmitted: (v) => v.trim().isEmpty ? null : _run(context, ref, v)),
                  ...body,
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- results

class SearchResultsScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  const SearchResultsScreen({super.key, this.initialQuery});
  @override
  ConsumerState<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends ConsumerState<SearchResultsScreen> {
  late final _ctl = TextEditingController(text: widget.initialQuery ?? '');
  final _f = AQFilters();

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _openFilters(List<Property> all) async {
    final next = await showAQFilterSheet(context, all: all, initial: _f, query: _ctl.text);
    if (next == null || !mounted) return;
    setState(() {
      _f.tx = next.tx;
      _f.category = next.category;
      _f.types..clear()..addAll(next.types);
      _f.areas..clear()..addAll(next.areas);
      _f.amenities..clear()..addAll(next.amenities);
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
    final async = ref.watch(aqAllPropertiesProvider);
    final q = _ctl.text.trim();
    final txIndex = _f.tx == null ? 0 : (_f.tx == TransactionType.buy ? 1 : 2);
    return AQViewingScaffold(
      maxWidth: aqListMaxWidth(context) == null ? null : aqListMaxWidth(context)! + AQSpacing.gutter * 2,
      title: f.t('srch.results'),
      subtitle: q.isEmpty ? null : f.t('srch.resultsFor', {'q': q}),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/search/start'),
      children: [
        AQQueryField(controller: _ctl, hint: f.t('srch.hint'), onChanged: (_) => setState(() {}), onSubmitted: (v) {
          _remember(ref, v);
          setState(() {});
        }),
        const SizedBox(height: AQSpacing.x3),
        AQSlideSwitch(labels: [f.t('disc.all'), f.t('home.buy'), f.t('home.rent')], index: txIndex, onChanged: (i) => setState(() => _f.tx = i == 0 ? null : (i == 1 ? TransactionType.buy : TransactionType.rent))),
        const SizedBox(height: AQSpacing.x2),
        Builder(builder: (context) {
          final label = q.isEmpty ? f.t('saved.s.all') : _ctl.text.trim();
          final saved = ref.watch(savedSearchesProvider).any((x) => x.label.toLowerCase() == label.toLowerCase());
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AQTextButton(
              label: saved ? f.t('saved.s.saved') : f.t('saved.s.save'),
              color: c.accentDeep,
              onPressed: saved ? null : () => setState(() => aqSaveSearch(ref, label, q)),
            ),
          );
        }),
        const SizedBox(height: AQSpacing.x2),
        async.when(
          loading: () => const Column(children: [AQSkeletonBox(height: 150), SizedBox(height: AQSpacing.x3), AQSkeletonBox(height: 150)]),
          error: (_, _) => AQErrorBanner(text: f.t('disc.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqAllPropertiesProvider))),
          data: (all) {
            final shown = _f.apply(all, query: q);
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Padding(padding: const EdgeInsets.only(bottom: AQSpacing.x3), child: AQResultsBar(count: shown.length, activeFilters: _f.activeCount, onFilters: () => _openFilters(all), onSort: () => showAQSortSheet(context, _f, () => setState(() {})))),
              if (shown.isEmpty)
                Column(children: [AQNoticeLine(text: f.t('props.empty')), if (_f.activeCount > 0 || _f.tx != null) AQSecondaryButton(label: f.t('flt.clear'), trailingChevron: false, onPressed: () => setState(_f.reset))])
              else
                AQResultGrid(children: [for (final p in shown) AQResultCard(property: p)]),
            ]);
          },
        ),
      ],
    );
  }
}
