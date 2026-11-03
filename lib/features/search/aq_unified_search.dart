import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_states.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/business.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../../data/repositories/app_state_providers.dart' show recentSearchesProvider, savedSearchesProvider;
import '../../data/repositories/providers.dart';
import '../role_home/mode_switch.dart';
import '../role_home/role_home_model.dart';
import '../role_home/role_home_widgets.dart' show RoleWorkspaceSwitcher;
import '../saved/saved_screen.dart' show aqSaveSearch;
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_cards.dart' show AQProfessionalCard, AQResultGrid, aqListMaxWidth;
import '../workspace/aq_home.dart' show AQLocationPill, AQResultCard, aqAllPropertiesProvider, homeAreaProvider;
import 'aq_filter_sheet.dart';
import 'aq_filters.dart';
import 'aq_search.dart' show AQQueryField;

enum _Scope { all, properties, professionals, services }

/// The one search page of AQARATI. The Explore tab is this page, and every search bar opens it. Typing
/// searches in place; the category row narrows what is shown; one Filters button opens one sheet; the
/// results appear below on the same page. Result cards still open their original detail screens.
class AQUnifiedSearch extends ConsumerStatefulWidget {
  final String? initialQuery;

  /// Put the cursor in the search field on arrival (when a search bar was tapped).
  final bool focus;
  const AQUnifiedSearch({super.key, this.initialQuery, this.focus = false});
  @override
  ConsumerState<AQUnifiedSearch> createState() => _AQUnifiedSearchState();
}

class _AQUnifiedSearchState extends ConsumerState<AQUnifiedSearch> {
  late final TextEditingController _ctl = TextEditingController(text: widget.initialQuery ?? '');
  _Scope _scope = _Scope.all;
  final AQFilters _f = AQFilters();
  BusinessCategory? _bizCat;
  bool _bizVerified = false;

  @override
  void initState() {
    super.initState();
    final area = ref.read(homeAreaProvider);
    if (area != null) _f.areas.add(area);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  String get _q => _ctl.text.trim();

  void _remember(String v) {
    final t = v.trim();
    if (t.isEmpty) return;
    ref.read(recentSearchesProvider.notifier).update((s) => [t, ...s.where((x) => x.toLowerCase() != t.toLowerCase())].take(6).toList());
  }

  bool _isService(Business b) => b.categories.contains(BusinessCategory.maintenance);

  /// Kinds of business a term points at. These are the same rules the old search used to send a term to the
  /// right directory ("AC repair" to maintenance, "architect" to architecture), so those searches still work.
  Set<BusinessCategory> _intent(String q) {
    final t = q.toLowerCase();
    return {
      if (RegExp(r'architect').hasMatch(t)) BusinessCategory.architecture,
      if (RegExp(r'interior|designer').hasMatch(t)) ...{BusinessCategory.interiorDesign, BusinessCategory.exteriorDesign},
      if (RegExp(r'\b(ac|plumb\w*|pool|repair|maintenance|cleaning|paint\w*|electric\w*|kitchen)\b').hasMatch(t)) BusinessCategory.maintenance,
      if (RegExp(r'contractor|construction|builder|engineer').hasMatch(t)) BusinessCategory.construction,
      if (RegExp(r'developer').hasMatch(t)) BusinessCategory.propertyDevelopment,
      if (RegExp(r'agent|broker').hasMatch(t)) BusinessCategory.realEstateAgent,
    };
  }

  bool _bizMatches(FlowStrings f, Business b) {
    final words = _q.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    final hay = '${b.name} ${b.description} ${b.locationLabel} ${b.categories.map((k) => '${k.label} ${f.t('bcat.${k.name}')}').join(' ')}'.toLowerCase();
    final byText = words.every(hay.contains);
    final byKind = _q.isNotEmpty && _intent(_q).any(b.categories.contains);
    return (byText || byKind) && (_bizCat == null || b.categories.contains(_bizCat)) && (!_bizVerified || b.verification.isVerified);
  }

  int get _activeCount => _scope == _Scope.professionals || _scope == _Scope.services
      ? (_bizCat != null ? 1 : 0) + (_bizVerified ? 1 : 0)
      : _f.activeCount + (_f.tx != null ? 1 : 0);

  void _resetFilters() => setState(() {
        _f.reset();
        _bizCat = null;
        _bizVerified = false;
      });

  Future<void> _openFilters(List<Property> all) async {
    final f = FlowStrings.of(context);
    if (_scope == _Scope.professionals || _scope == _Scope.services) {
      final result = await _bizSheet(f);
      if (result == null || !mounted) return;
      setState(() {
        _bizCat = result.$1;
        _bizVerified = result.$2;
      });
      return;
    }
    final next = await showAQFilterSheet(context, all: all, initial: _f, query: _q);
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

  /// The same one-sheet filter pattern for businesses: what they do, and verified only.
  Future<(BusinessCategory?, bool)?> _bizSheet(FlowStrings f) {
    var cat = _bizCat;
    var verified = _bizVerified;
    final cats = [for (final k in BusinessCategory.values) if ((_scope == _Scope.services) == (k == BusinessCategory.maintenance)) k];
    return showAQSheet<(BusinessCategory?, bool)>(
      context,
      useRootNavigator: true,
      builder: (sheet) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(header: true, child: Text(f.t('flt.title'), style: AQTypography.of(sheet, AQText.headlineSmall))),
              const SizedBox(height: AQSpacing.x4),
              if (cats.length > 1) ...[
                Text(f.t('flt.type'), style: AQTypography.of(sheet, AQText.titleSmall)),
                const SizedBox(height: AQSpacing.x2),
                Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                  AQChoicePill(label: f.t('flt.all'), selected: cat == null, onTap: () => setSheet(() => cat = null)),
                  for (final k in cats) AQChoicePill(label: f.t('bcat.${k.name}'), selected: cat == k, onTap: () => setSheet(() => cat = cat == k ? null : k)),
                ]),
                const SizedBox(height: AQSpacing.x4),
              ],
              AQCheckToggle(label: f.t('pro.verified'), value: verified, onChanged: (v) => setSheet(() => verified = v)),
              const SizedBox(height: AQSpacing.x4),
              Row(children: [
                Expanded(child: AQSecondaryButton(label: f.t('flt.reset'), trailingChevron: false, onPressed: () => setSheet(() {
                      cat = null;
                      verified = false;
                    }))),
                const SizedBox(width: AQSpacing.x3),
                Expanded(child: AQPrimaryButton(label: f.t('flt.apply'), trailingChevron: false, onPressed: () => Navigator.of(sheet).pop((cat, verified)))),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  List<(String, VoidCallback)> _chips(FlowStrings f) {
    String type(PropertyType t) => FlowStrings.keys.contains('ptype.${t.name}') ? f.t('ptype.${t.name}') : t.label;
    if (_scope == _Scope.professionals || _scope == _Scope.services) {
      return [
        if (_bizCat != null) (f.t('bcat.${_bizCat!.name}'), () => setState(() => _bizCat = null)),
        if (_bizVerified) (f.t('pro.verified'), () => setState(() => _bizVerified = false)),
      ];
    }
    return [
      if (_f.tx != null) (_f.tx == TransactionType.buy ? f.t('home.buy') : f.t('home.rent'), () => setState(() => _f.tx = null)),
      if (_f.category != null) (f.t(_f.category!.key), () => setState(() => _f.category = null)),
      for (final t in _f.types.toList()) (type(t), () => setState(() => _f.types.remove(t))),
      for (final a in _f.areas.toList()) (a, () => setState(() => _f.areas.remove(a))),
      if (_f.minPrice != null || _f.maxPrice != null)
        ('OMR ${_f.minPrice == null ? '' : VFmt.n(context, _f.minPrice!.round())}–${_f.maxPrice == null ? '' : VFmt.n(context, _f.maxPrice!.round())}', () => setState(() => _f.minPrice = _f.maxPrice = null)),
      if (_f.beds != null) ('${VFmt.n(context, _f.beds!)}+ ${f.t('flt.beds')}', () => setState(() => _f.beds = null)),
      if (_f.baths != null) ('${VFmt.n(context, _f.baths!)}+ ${f.t('flt.baths')}', () => setState(() => _f.baths = null)),
      if (_f.minArea != null) ('${VFmt.n(context, _f.minArea!)}+ m²', () => setState(() => _f.minArea = null)),
      for (final a in _f.amenities.toList()) (a, () => setState(() => _f.amenities.remove(a))),
      if (_f.verifiedOnly) (f.t('flt.verified'), () => setState(() => _f.verifiedOnly = false)),
    ];
  }

  Widget _barButton(BuildContext context, {required String icon, required String label, int badge = 0, required VoidCallback onTap}) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: badge > 0 ? '$label, $badge' : label,
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: () {
          AQHaptics.selection();
          onTap();
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: AQControl.tap - 4),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3),
          decoration: BoxDecoration(color: badge > 0 ? c.surfaceSelected : c.surfaceRaised, borderRadius: BorderRadius.circular(AQControl.tap), border: Border.all(color: badge > 0 ? c.accent : c.hairline)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            AQIcon(icon, size: 18, color: c.accentDeep),
            const SizedBox(width: 6),
            Text(label, style: AQTypography.of(context, AQText.labelMedium)),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(color: c.accent, borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text(VFmt.n(context, badge), style: AQTypography.of(context, AQText.labelSmall, color: c.onAccent))),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, VoidCallback onRemove) {
    final c = AQColors.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '${FlowStrings.of(context).t('srch.removeRecent', {'q': label})}',
      excludeSemantics: true,
      onTap: onRemove,
      child: AQPressable(
        onTap: onRemove,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsetsDirectional.only(start: AQSpacing.x3, end: AQSpacing.x2),
          decoration: BoxDecoration(color: c.surfaceSelected, borderRadius: BorderRadius.circular(18), border: Border.all(color: c.accent.withValues(alpha: 0.4))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.labelMedium, color: c.accentDeep))),
            const SizedBox(width: 4),
            AQIcon('close', size: 14, color: c.accentDeep),
          ]),
        ),
      ),
    );
  }

  Widget _sectionHead(BuildContext context, String title, String? action, VoidCallback? onAction) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x5, bottom: AQSpacing.x3),
      child: Row(children: [
        Expanded(child: Semantics(header: true, liveRegion: true, child: Text(title, style: AQTypography.of(context, AQText.headlineSmall)))),
        if (action != null) AQTextButton(label: action, color: c.accentDeep, trailingIcon: 'chevron-right', onPressed: onAction),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    // The location pill in the corner drives the same area filter for properties.
    ref.listen<String?>(homeAreaProvider, (_, area) => setState(() {
          _f.areas.clear();
          if (area != null) _f.areas.add(area);
        }));
    final props = ref.watch(aqAllPropertiesProvider);
    final biz = ref.watch(businessesProvider);
    final recents = ref.watch(recentSearchesProvider);
    final saved = ref.watch(savedSearchesProvider);
    final res = ref.watch(homeResolutionProvider);
    final maxW = aqListMaxWidth(context);

    final showProps = _scope == _Scope.all || _scope == _Scope.properties;
    final showPros = _scope == _Scope.all || _scope == _Scope.professionals;
    final showServices = _scope == _Scope.all || _scope == _Scope.services;
    final propsHit = props.valueOrNull == null ? <Property>[] : _f.apply(props.value!, query: _q);
    final bizAll = biz.valueOrNull ?? const <Business>[];
    final prosHit = [for (final b in bizAll) if (!_isService(b) && _bizMatches(f, b)) b];
    final servicesHit = [for (final b in bizAll) if (_isService(b) && _bizMatches(f, b)) b];
    // Property-only filters hide professionals and services from "All" so a price or bedroom filter never mixes kinds.
    final propFiltersOn = _f.activeCount > 0 || _f.tx != null;
    final all = _scope == _Scope.all;
    final propsShown = showProps ? propsHit : const <Property>[];
    final prosShown = showPros && !(all && propFiltersOn) ? prosHit : const <Business>[];
    final servicesShown = showServices && !(all && propFiltersOn) ? servicesHit : const <Business>[];
    final loading = (props.isLoading && !props.hasValue) || (biz.isLoading && !biz.hasValue);
    final failed = props.hasError && biz.hasError;
    final empty = propsShown.isEmpty && prosShown.isEmpty && servicesShown.isEmpty;
    final chips = _chips(f);
    final label = _q.isEmpty ? f.t('saved.s.all') : _q;
    final isSaved = saved.any((x) => x.label.toLowerCase() == label.toLowerCase());
    final sortable = _scope == _Scope.all || _scope == _Scope.properties;

    Widget scopeChip(_Scope s, String text) => AQChoicePill(label: text, selected: _scope == s, onTap: () => setState(() => _scope = s));

    Widget grid(List<Widget> cards) => AQResultGrid(children: cards);

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW == null ? AQSpacing.maxContent + AQSpacing.gutter * 2 : maxW + AQSpacing.gutter * 2),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x4, AQSpacing.gutter, 128),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: Semantics(header: true, child: Text(f.t('explore.title'), style: AQTypography.of(context, AQText.displaySmall)))),
                    const AQLocationPill(),
                  ]),
                  if (hasWorkSide(res))
                    Padding(
                      padding: const EdgeInsets.only(top: AQSpacing.x2),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: RoleWorkspaceSwitcher(selected: HomeWorkspace.buyer, onChanged: (w) => w == HomeWorkspace.agent ? switchToWork(context, ref) : null),
                      ),
                    ),
                  const SizedBox(height: AQSpacing.x4),
                  AQQueryField(
                    controller: _ctl,
                    hint: f.t('home.search.hint'),
                    autofocus: widget.focus,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (v) {
                      _remember(v);
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: AQSpacing.x3),
                  // The four kinds wrap onto a second line on narrow phones instead of scrolling out of view.
                  Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                    scopeChip(_Scope.all, f.t('flt.all')),
                    scopeChip(_Scope.properties, f.t('srch.tile.props')),
                    scopeChip(_Scope.professionals, f.t('srch.tile.pros')),
                    scopeChip(_Scope.services, f.t('hm8.services')),
                  ]),
                  const SizedBox(height: AQSpacing.x3),
                  Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    _barButton(context, icon: 'sliders', label: f.t('flt.button'), badge: _activeCount, onTap: () => _openFilters(props.valueOrNull ?? const <Property>[])),
                    if (sortable) _barButton(context, icon: 'chevron-down', label: f.t('sort.button'), onTap: () => showAQSortSheet(context, _f, () => setState(() {}))),
                    if (_q.isNotEmpty && showProps)
                      AQTextButton(label: isSaved ? f.t('saved.s.saved') : f.t('saved.s.save'), color: c.accentDeep, onPressed: isSaved ? null : () => setState(() => aqSaveSearch(ref, label, _q))),
                  ]),
                  if (chips.isNotEmpty) ...[
                    const SizedBox(height: AQSpacing.x3),
                    Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      for (final ch in chips) _chip(context, ch.$1, ch.$2),
                      AQTextButton(label: f.t('flt.clear'), color: c.accentDeep, onPressed: _resetFilters),
                    ]),
                  ],
                  if (_q.isEmpty && recents.isNotEmpty) ...[
                    const SizedBox(height: AQSpacing.x4),
                    Row(children: [
                      Expanded(child: Text(f.t('srch.recent'), style: AQTypography.of(context, AQText.labelMedium, soft: true))),
                      AQTextButton(label: f.t('srch.clearRecent'), color: c.inkSoft, onPressed: () => ref.read(recentSearchesProvider.notifier).state = const []),
                    ]),
                    const SizedBox(height: AQSpacing.x1),
                    Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
                      for (final r in recents)
                        AQChoicePill(
                          label: r,
                          selected: false,
                          onTap: () => setState(() {
                            _ctl.text = r;
                            _ctl.selection = TextSelection.collapsed(offset: r.length);
                          }),
                        ),
                    ]),
                  ],
                  if (loading) ...[
                    const SizedBox(height: AQSpacing.x5),
                    const AQLoadingBlock(height: 260),
                    const SizedBox(height: AQSpacing.x3),
                    const AQLoadingBlock(height: 260),
                  ] else if (failed)
                    AQErrorState(
                      title: f.t('disc.loadError'),
                      retryLabel: f.t('common.retry'),
                      onRetry: () {
                        ref.invalidate(aqAllPropertiesProvider);
                        ref.invalidate(businessesProvider);
                      },
                    )
                  else if (empty)
                    AQEmptyState(
                      icon: 'search',
                      title: _q.isEmpty ? f.t('flt.none') : f.t('srch.noMatch', {'q': _q}),
                      actionLabel: (_activeCount > 0 || _q.isNotEmpty) ? f.t('flt.clear') : null,
                      onAction: () => setState(() {
                        _resetFilters();
                        _ctl.clear();
                      }),
                    )
                  else ...[
                    if (propsShown.isNotEmpty) ...[
                      _sectionHead(context, f.t('props.count', {'n': VFmt.n(context, propsShown.length)}), all && propsShown.length > 4 ? f.t('srch.seeAll') : null, () => setState(() => _scope = _Scope.properties)),
                      grid([for (final p in (all ? propsShown.take(4) : propsShown)) AQResultCard(property: p)]),
                    ],
                    if (prosShown.isNotEmpty) ...[
                      _sectionHead(context, f.t('pro.count', {'n': VFmt.n(context, prosShown.length)}), all && prosShown.length > 4 ? f.t('srch.seeAll') : null, () => setState(() => _scope = _Scope.professionals)),
                      grid([for (final b in (all ? prosShown.take(4) : prosShown)) AQProfessionalCard(business: b, detailed: true)]),
                    ],
                    if (servicesShown.isNotEmpty) ...[
                      _sectionHead(context, '${f.t('hm8.services')} · ${VFmt.n(context, servicesShown.length)}', all && servicesShown.length > 4 ? f.t('srch.seeAll') : null, () => setState(() => _scope = _Scope.services)),
                      grid([for (final b in (all ? servicesShown.take(4) : servicesShown)) AQProfessionalCard(business: b, detailed: true)]),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
