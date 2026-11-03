import '../viewing/widgets/viewing_scaffold.dart' show AQShellInset;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/config/maps_config.dart';
import '../../core/localization/flow_strings.dart';
import '../../core/widgets/aqarati_map_view.dart';
import '../../data/models/enums.dart';
import '../../data/models/property.dart';
import '../viewing/widgets/viewing_format.dart';
import '../workspace/aq_home.dart';
import 'aq_filter_sheet.dart';
import 'aq_filters.dart';

const _muscat = LatLng(23.5880, 58.3829);

/// List | map switch shown in the top corner of both browse screens.
class AQViewToggle extends StatelessWidget {
  final bool map;
  final VoidCallback onList, onMap;
  const AQViewToggle({
    super.key,
    required this.map,
    required this.onList,
    required this.onMap,
  });

  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    Widget seg(String icon, String label, bool on, VoidCallback tap) =>
        Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          selected: on,
          label: label,
          excludeSemantics: true,
      onTap: () {
              if (!on) AQHaptics.selection();
              if (!on) tap();
            },
          child: AQPressable(
            onTap: () {
              if (!on) AQHaptics.selection();
              if (!on) tap();
            },
            child: AnimatedContainer(
              duration: AQMotion.scaled(context, AQMotion.fast),
              width: 48,
              height: 44,
              decoration: BoxDecoration(
                color: on ? c.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: icon == 'list'
                    ? Icon(Icons.view_agenda_outlined, size: 22, color: on ? c.onAccent : c.inkSoft)
                    : AQIcon(icon, size: 22, color: on ? c.onAccent : c.inkSoft),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg('list', f.t('map.list'), !map, onList),
          seg('pin', f.t('map.map'), map, onMap),
        ],
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  final String label;
  final bool selected;
  const _Pin({required this.label, required this.selected});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    return AnimatedContainer(
      duration: AQMotion.scaled(context, AQMotion.fast),
      padding: const EdgeInsets.symmetric(
        horizontal: AQSpacing.x3,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: selected ? c.accent : c.surfaceRaised,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? c.accent : c.hairline),
        boxShadow: AQElevation.floating,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: selected ? c.onAccent : c.accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            VFmt.iso(label),
            maxLines: 1,
            style: AQTypography.of(
              context,
              AQText.labelMedium,
              color: selected ? c.onAccent : c.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class AQMapScreen extends ConsumerStatefulWidget {
  final String? tx;
  const AQMapScreen({super.key, this.tx});
  @override
  ConsumerState<AQMapScreen> createState() => _AQMapScreenState();
}

class _AQMapScreenState extends ConsumerState<AQMapScreen> {
  late final AQFilters _f = AQFilters(
    tx: switch (widget.tx) {
      'buy' => TransactionType.buy,
      'rent' => TransactionType.rent,
      _ => null,
    },
  );
  final _pages = PageController(viewportFraction: 0.92);
  GoogleMapController? _map;
  final Map<String, Offset> _pos = {};
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    final area = ref.read(homeAreaProvider);
    if (area != null) _f.areas.add(area);
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _project(List<Property> located) async {
    if (kIsWeb) return;
    final map = _map;
    if (map == null || !mounted) return;
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final next = <String, Offset>{};
    for (final p in located) {
      final s = await map.getScreenCoordinate(
        LatLng(p.latitude!, p.longitude!),
      );
      next[p.id] = Offset(s.x / dpr, s.y / dpr);
    }
    if (mounted)
      setState(
        () => _pos
          ..clear()
          ..addAll(next),
      );
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
      _selectedId = null;
    });
  }

  void _select(List<Property> shown, Property p, {bool scroll = true}) {
    setState(() => _selectedId = p.id);
    if (scroll && _pages.hasClients)
      _pages.animateToPage(
        shown.indexOf(p),
        duration: AQMotion.scaled(context, AQMotion.standard),
        curve: AQMotion.standardCurve,
      );
    final lat = p.latitude, lng = p.longitude;
    if (!kIsWeb && lat != null && lng != null)
      _map?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final async = ref.watch(aqAllPropertiesProvider);
    final area = ref.watch(homeAreaProvider);
    final all = async.valueOrNull ?? const <Property>[];
    final shown = _f.apply(all);
    final located = [
      for (final p in shown)
        if (p.latitude != null && p.longitude != null) p,
    ];
    final selected =
        shown.where((p) => p.id == _selectedId).firstOrNull ??
        (shown.isEmpty ? null : shown.first);
    final focus = selected != null && selected.latitude != null
        ? LatLng(selected.latitude!, selected.longitude!)
        : (located.isNotEmpty
              ? LatLng(located.first.latitude!, located.first.longitude!)
              : _muscat);
    final large = aqLargeText(context);
    final pinOverlay = !kIsWeb && kGoogleMapsConfigured;

    final top = Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.background,
            c.background.withValues(alpha: 0.96),
            c.background.withValues(alpha: 0),
          ],
          stops: const [0, 0.72, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AQSpacing.x2,
            AQSpacing.x1,
            AQSpacing.gutter,
            AQSpacing.x4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AQIconButton(
                    icon: 'chevron-left',
                    semanticsLabel: f.t('common.back'),
                    onPressed: () => aqBack(context, '/properties/all'),
                  ),
                  Expanded(
                    child: Text(
                      f.t('home.props'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AQTypography.of(context, AQText.titleMedium),
                    ),
                  ),
                  AQViewToggle(
                    map: true,
                    onMap: () {},
                    onList: () => aqBack(context, '/properties/all'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AQSpacing.x4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      liveRegion: true,
                      child: Text(
                        f.t('map.count', {'n': VFmt.n(context, shown.length)}),
                        style: AQTypography.of(
                          context,
                          large ? AQText.headlineLarge : AQText.displaySmall,
                        ),
                      ),
                    ),
                    Text(
                      f.t('map.sub', {'area': area ?? f.t('home.loc.all')}),
                      style: AQTypography.of(
                        context,
                        AQText.bodySmall,
                        soft: true,
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    Semantics(
                      button: true,
                      focusable: true,
                      onFocus: () {},
                      label: f.t('map.search'),
                      excludeSemantics: true,
      onTap: () => context.push('/search/start'),
                      child: AQPressable(
                        onTap: () => context.push('/search/start'),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 52),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AQSpacing.x4,
                          ),
                          decoration: BoxDecoration(
                            color: c.surfaceRaised,
                            borderRadius: BorderRadius.circular(26),
                            boxShadow: AQElevation.floating,
                            border: Border.all(color: c.hairline),
                          ),
                          child: Row(
                            children: [
                              AQIcon('search', size: 20, color: c.ink),
                              const SizedBox(width: AQSpacing.x3),
                              Expanded(
                                child: Text(
                                  f.t('map.search'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AQTypography.of(
                                    context,
                                    AQText.bodyMedium,
                                    color: c.inkFaint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AQSpacing.x3),
                    Wrap(
                      spacing: AQSpacing.x2,
                      runSpacing: AQSpacing.x2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AQChoicePill(
                          label: f.t('home.buy'),
                          selected: _f.tx == TransactionType.buy,
                          onTap: () => setState(() {
                            _f.tx = _f.tx == TransactionType.buy
                                ? null
                                : TransactionType.buy;
                            _f.minPrice = _f.maxPrice = null;
                            _selectedId = null;
                          }),
                        ),
                        AQChoicePill(
                          label: f.t('home.rent'),
                          selected: _f.tx == TransactionType.rent,
                          onTap: () => setState(() {
                            _f.tx = _f.tx == TransactionType.rent
                                ? null
                                : TransactionType.rent;
                            _f.minPrice = _f.maxPrice = null;
                            _selectedId = null;
                          }),
                        ),
                        _FilterButton(
                          count: _f.activeCount,
                          onTap: () => _openFilters(all),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final bottomH = 292.0;
    final sheetBody = <Widget>[
      const SizedBox(height: AQSpacing.x3),
      Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: c.hairline, borderRadius: BorderRadius.circular(2)))),
      Padding(
        padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, AQSpacing.x2, AQSpacing.gutter, AQSpacing.x2),
        child: Row(children: [
          Expanded(child: Text(f.t('props.count', {'n': VFmt.n(context, shown.length)}), style: AQTypography.of(context, AQText.titleMedium))),
          AQTextButton(label: f.t('sort.${_f.sort.name}'), color: c.accentDeep, trailingIcon: 'chevron-down', onPressed: () => showAQSortSheet(context, _f, () => setState(() {}))),
        ]),
      ),
    ];
    Widget emptyOrLoading() => async.isLoading && all.isEmpty
        ? const Padding(padding: EdgeInsets.symmetric(horizontal: AQSpacing.gutter), child: AQSkeletonBox(height: 150))
        : Padding(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter), child: Column(mainAxisSize: MainAxisSize.min, children: [AQNoticeLine(text: f.t('props.empty')), if (_f.activeCount > 0 || _f.tx != null) AQSecondaryButton(label: f.t('flt.clear'), compact: true, trailingChevron: false, onPressed: () => setState(_f.reset))]));
    final note = shown.length > located.length
        ? Padding(padding: const EdgeInsets.fromLTRB(AQSpacing.gutter, 2, AQSpacing.gutter, AQSpacing.x1), child: Text(f.t('map.noLocation', {'n': VFmt.n(context, shown.length - located.length)}), style: AQTypography.of(context, AQText.bodySmall, soft: true)))
        : const SizedBox.shrink();

    final mapView = AqaratiMapView(
      // Web is a keyless embed with no camera API, so it is rebuilt around the selected listing.
      key: kIsWeb ? ValueKey(selected?.id) : null,
      initialCenter: focus,
      initialZoom: kIsWeb ? 13 : 11,
      borderRadius: BorderRadius.zero,
      // The header, filters and the strip/sheet cover the top and bottom of the map; messages sit between them.
      overlayInsets: EdgeInsets.only(top: 250, bottom: bottomH + 190),
      onMapCreated: (m) {
        _map = m;
        _project(located);
      },
      onCameraMove: () => _project(located),
      onCameraIdle: () => _project(located),
    );
    final pins = [
      if (pinOverlay)
        for (final p in located)
          if (_pos[p.id] != null) Positioned(left: _pos[p.id]!.dx - 40, top: _pos[p.id]!.dy - 36, child: GestureDetector(onTap: () => _select(shown, p), child: _Pin(label: p.price.compact, selected: selected?.id == p.id))),
    ];
    // Web (and native without a key) cannot project pins onto the map; the same price pills sit in a strip instead.
    Widget strip() => SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter),
            itemCount: located.length,
            separatorBuilder: (_, _) => const SizedBox(width: AQSpacing.x2),
            itemBuilder: (context, i) {
              final p = located[i];
              return Semantics(
                button: true,
                focusable: true,
                onFocus: () {},
                selected: selected?.id == p.id,
                label: '${p.title}, ${p.price.compact}',
                excludeSemantics: true,
      onTap: () => _select(shown, p),
                child: AQPressable(onTap: () => _select(shown, p), child: _Pin(label: p.price.compact, selected: selected?.id == p.id)),
              );
            },
          ),
        );
    final showStrip = !pinOverlay && located.isNotEmpty;
    // The shared customer navigation floats over the bottom of the screen: leave it room.
    final navInset = AQShellInset.of(context);

    // Large text: the screen scrolls as one column so nothing is covered.
    if (large) {
      return Scaffold(
        backgroundColor: c.background,
        body: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            top,
            SizedBox(height: 300, child: Stack(children: [Positioned.fill(child: mapView), ...pins, if (showStrip) Positioned(left: 0, right: 0, bottom: AQSpacing.x3, child: strip())])),
            DecoratedBox(
              decoration: BoxDecoration(color: c.surfaceRaised, boxShadow: AQElevation.modal),
              child: SafeArea(
                top: false,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...sheetBody,
                  if (selected == null) emptyOrLoading() else Padding(padding: const EdgeInsets.symmetric(horizontal: AQSpacing.gutter), child: AQResultCard(property: selected, compact: true)),
                  note,
                  SizedBox(height: AQSpacing.x4 + navInset),
                ]),
              ),
            ),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.background,
      body: Stack(children: [
        Positioned.fill(child: mapView),
        ...pins,
        Positioned(left: 0, right: 0, top: 0, child: top),
        if (showStrip) Positioned(left: 0, right: 0, bottom: bottomH + navInset + (navInset == 0 ? MediaQuery.paddingOf(context).bottom : 0) + AQSpacing.x3, child: strip()),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(bottom: navInset),
            child: DecoratedBox(
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: const BorderRadius.vertical(top: Radius.circular(AQRadius.large)), boxShadow: AQElevation.modal),
            child: SafeArea(
              top: false,
              bottom: navInset == 0,
              child: SizedBox(
                height: bottomH,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ...sheetBody,
                  Expanded(
                    child: shown.isEmpty
                        ? Center(child: emptyOrLoading())
                        : PageView.builder(
                            controller: _pages,
                            itemCount: shown.length,
                            onPageChanged: (i) => _select(shown, shown[i], scroll: false),
                            itemBuilder: (context, i) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: AQResultCard(property: shown[i], compact: true))),
                          ),
                  ),
                  note,
                  const SizedBox(height: AQSpacing.x2),
                ]),
              ),
            ),
          ),
          ),
        ),
      ]),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _FilterButton({required this.count, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: count > 0 ? '${f.t('flt.button')}, $count' : f.t('flt.button'),
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
          constraints: const BoxConstraints(minHeight: AQControl.tap - 4),
          padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x4),
          decoration: BoxDecoration(
            color: count > 0 ? c.surfaceSelected : c.surface,
            borderRadius: BorderRadius.circular(AQControl.tap),
            border: Border.all(color: count > 0 ? c.accent : c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                f.t('flt.button'),
                style: AQTypography.of(
                  context,
                  AQText.labelMedium,
                  color: c.inkSoft,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  constraints: const BoxConstraints(minWidth: 20),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: c.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      VFmt.n(context, count),
                      style: AQTypography.of(
                        context,
                        AQText.labelSmall,
                        color: c.onAccent,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
