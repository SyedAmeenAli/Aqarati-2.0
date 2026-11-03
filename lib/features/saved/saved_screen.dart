import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/aq/aq_forms.dart';
import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_scene.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/models/saved.dart';
import '../../data/repositories/app_state_providers.dart';
import '../viewing/widgets/viewing_format.dart';
import '../viewing/widgets/viewing_scaffold.dart';
import '../workspace/aq_home.dart' show AQResultCard, AQSkeletonBox, AQSlideSwitch, aqAllPropertiesProvider;

/// Saved properties (with compare) and saved searches.
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});
  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  int _tab = 0;
  final _compare = <String>[];
  static const _maxCompare = 3;

  Widget _empty(BuildContext context, {required String icon, required String title, required String body, required String cta, required VoidCallback onTap}) {
    final c = AQColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AQSpacing.x8),
      child: Column(children: [
        Container(width: 72, height: 72, decoration: BoxDecoration(color: c.surfaceSelected, shape: BoxShape.circle), child: Center(child: AQIcon(icon, size: 32, color: c.accent))),
        const SizedBox(height: AQSpacing.x4),
        Text(title, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.headlineSmall)),
        const SizedBox(height: AQSpacing.x2),
        Text(body, textAlign: TextAlign.center, style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        const SizedBox(height: AQSpacing.x5),
        AQPrimaryButton(label: cta, trailingChevron: false, onPressed: onTap),
      ]),
    );
  }

  Widget _properties(BuildContext context, FlowStrings f) {
    final c = AQColors.of(context);
    final ids = ref.watch(savedPropertyIdsProvider);
    if (ids.isEmpty) {
      return _empty(context, icon: 'bookmark', title: f.t('saved.empty.t'), body: f.t('saved.empty.b'), cta: f.t('saved.empty.cta'), onTap: () => context.go('/app/explore'));
    }
    final async = ref.watch(aqAllPropertiesProvider);
    return async.when(
      loading: () => const Column(children: [AQSkeletonBox(height: 140), SizedBox(height: AQSpacing.x3), AQSkeletonBox(height: 140)]),
      error: (_, _) => AQErrorBanner(text: f.t('disc.loadError'), action: AQTextButton(label: f.t('common.retry'), color: c.accent, onPressed: () => ref.invalidate(aqAllPropertiesProvider))),
      data: (all) {
        final saved = [for (final p in all) if (ids.contains(p.id)) p];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AQSpacing.x3),
            child: Text(saved.length > 1 ? f.t('saved.count.compare', {'n': VFmt.n(context, saved.length), 'm': VFmt.n(context, _maxCompare)}) : f.t('saved.count', {'n': VFmt.n(context, saved.length)}), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
          ),
          for (final p in saved)
            Padding(
              padding: const EdgeInsets.only(bottom: AQSpacing.x3),
              child: Stack(children: [
                AQResultCard(property: p, trailingInset: saved.length > 1 ? 40 : 0),
                if (saved.length > 1)
                  PositionedDirectional(
                    end: 6,
                    top: 6,
                    child: Semantics(
                      button: true,
                      focusable: true,
                      onFocus: () {},
                      selected: _compare.contains(p.id),
                      label: f.t('saved.select', {'t': p.title}),
                      excludeSemantics: true,
      onTap: () {
                          AQHaptics.selection();
                          setState(() {
                            if (_compare.contains(p.id)) {
                              _compare.remove(p.id);
                            } else if (_compare.length < _maxCompare) {
                              _compare.add(p.id);
                            }
                          });
                        },
                      child: AQPressable(
                        onTap: () {
                          AQHaptics.selection();
                          setState(() {
                            if (_compare.contains(p.id)) {
                              _compare.remove(p.id);
                            } else if (_compare.length < _maxCompare) {
                              _compare.add(p.id);
                            }
                          });
                        },
                        pressedScale: 0.9,
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Center(
                            child: AnimatedContainer(
                              duration: AQMotion.scaled(context, AQMotion.fast),
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(color: _compare.contains(p.id) ? c.accent : c.surfaceRaised, shape: BoxShape.circle, border: Border.all(color: _compare.contains(p.id) ? c.accent : c.hairline, width: 1.5)),
                              child: _compare.contains(p.id) ? Center(child: AQIcon('check', size: 16, color: c.onAccent)) : null,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
        ]);
      },
    );
  }

  Widget _searches(BuildContext context, FlowStrings f) {
    final c = AQColors.of(context);
    final list = ref.watch(savedSearchesProvider);
    if (list.isEmpty) {
      return _empty(context, icon: 'search', title: f.t('saved.s.empty.t'), body: f.t('saved.s.empty.b'), cta: f.t('saved.s.empty.cta'), onTap: () => context.push('/search/start'));
    }
    return Column(children: [
      for (final s in list)
        Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x3),
          child: Container(
            decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
            child: Row(children: [
              Expanded(
                child: Semantics(
                  button: true,
                  focusable: true,
                  onFocus: () {},
                  label: f.t('saved.s.open', {'q': s.label}),
                  excludeSemantics: true,
      onTap: () => context.push('/search?q=${Uri.encodeQueryComponent(s.filters['q'] ?? '')}'),
                  child: AQPressable(
                    onTap: () => context.push('/search?q=${Uri.encodeQueryComponent(s.filters['q'] ?? '')}'),
                    pressedScale: 0.99,
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 72),
                      padding: const EdgeInsets.all(AQSpacing.x4),
                      child: Row(children: [
                        AQIcon('search', size: 22, color: c.accent),
                        const SizedBox(width: AQSpacing.x3),
                        Expanded(child: Text(VFmt.iso(s.label), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleMedium))),
                      ]),
                    ),
                  ),
                ),
              ),
              AQIconButton(icon: 'close', directional: false, semanticsLabel: f.t('saved.s.remove', {'q': s.label}), onPressed: () => ref.read(savedSearchesProvider.notifier).update((x) => x.where((e) => e.id != s.id).toList())),
            ]),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    // Drop selections for properties that were un-saved elsewhere.
    final ids = ref.watch(savedPropertyIdsProvider);
    _compare.removeWhere((id) => !ids.contains(id));
    return AQViewingScaffold(
      title: f.t('saved.title'),
      subtitle: f.t('saved.sub'),
      backLabel: f.t('common.back'),
      onBack: () => aqBack(context, '/app/account'),
      bottom: _tab == 0 && _compare.length >= 2
          ? AQBottomActionBar(
              primary: AQPrimaryButton(
                label: f.t('saved.compare', {'n': VFmt.n(context, _compare.length)}),
                trailingChevron: false,
                onPressed: () => context.push('/compare?ids=${_compare.join(',')}'),
              ),
            )
          : null,
      children: [
        AQSlideSwitch(labels: [f.t('saved.tab.props'), f.t('saved.tab.searches')], index: _tab, onChanged: (i) => setState(() => _tab = i)),
        const SizedBox(height: AQSpacing.x4),
        AnimatedSwitcher(duration: AQMotion.scaled(context, AQMotion.standard), child: KeyedSubtree(key: ValueKey(_tab), child: _tab == 0 ? _properties(context, f) : _searches(context, f))),
      ],
    );
  }
}

/// Adds the current search to the saved list unless it is already there.
bool aqSaveSearch(WidgetRef ref, String label, String query) {
  final list = ref.read(savedSearchesProvider);
  if (list.any((s) => s.label.toLowerCase() == label.toLowerCase())) return false;
  ref.read(savedSearchesProvider.notifier).state = [SavedSearch(id: DateTime.now().microsecondsSinceEpoch.toString(), label: label, filters: {'q': query}, createdAt: DateTime.now()), ...list];
  return true;
}
