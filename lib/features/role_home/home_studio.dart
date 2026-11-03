import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/domain/account_models.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_models.dart';
import '../devbuild/db_repository.dart';
import '../devbuild/db_service_toggles.dart';
import '../search/aq_filter_sheet.dart' show AQChoicePill;
import '../devbuild/db_widgets.dart' show DbNotice, DbSkeleton, dbTypeImage;
import 'role_home_model.dart';
import 'role_home_widgets.dart';
import '../ads/ad_models.dart' show AdAudience;
import '../ads/sponsored_banner.dart';
import '../analytics/analytics_screens.dart' show RoleKpiStrip;

/// Building Architecture: a quiet editorial studio page. Whitespace, fine rules, a numbered
/// index and the real bio set as a quotation. It is a profile home: the developer's project
/// manager does not exist for this role, and portfolio publishing is shown as proposed.
class ArchitectureHome extends ConsumerWidget {
  const ArchitectureHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final accent = roleAccent(context, HomeRole.architecture);
    final org = ref.watch(dbMyOrgProvider);
    final o = org.valueOrNull;
    void profile() => context.push('/app/account/workspace/profile');
    void reviews() => context.push('/app/account/workspace/reviews');
    void directory() => context.go('/app/explore/build/results?cat=architecture');

    Widget indexItem(String n, String label, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            focusable: true,
            onFocus: () {},
            label: label,
            excludeSemantics: true,
      onTap: onTap,
            child: AQPressable(
              onTap: onTap,
              child: Container(
                constraints: const BoxConstraints(minHeight: AQControl.tap),
                padding: const EdgeInsets.symmetric(vertical: AQSpacing.x2),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n, style: AQTypography.of(context, AQText.headlineSmall, color: accent)),
                  FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(label, style: AQTypography.of(context, AQText.labelSmall, color: c.inkSoft).copyWith(letterSpacing: 1.2))),
                ]),
              ),
            ),
          ),
        );

    return RoleHomePage(children: [
      const RoleReveal(child: RoleHeader()),
      RoleReveal(
        index: 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RoleEyebrow(f.t('rh.arc.eyebrow'), color: accent),
          const SizedBox(height: AQSpacing.x2),
          Semantics(header: true, child: Text(f.t('rh.arc.title'), style: AQTypography.of(context, AQText.displayMedium))),
          const SizedBox(height: AQSpacing.x2),
          Text(f.t('rh.arc.sub'), style: AQTypography.of(context, AQText.bodyMedium, soft: true)),
        ]),
      ),
      const SizedBox(height: AQSpacing.x5),
      // Asymmetric frame: the picture is inset from the start edge and sharp at one corner.
      RoleReveal(
        index: 2,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: AQSpacing.x6),
          child: RolePhotoPanel(
            image: dbTypeImage(ProType.architecture),
            title: f.t('rh.arc.hero'),
            aspect: 1.05,
            alignment: Alignment.center,
            radius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(AQRadius.small),
              topEnd: Radius.circular(AQRadius.large),
              bottomStart: Radius.circular(AQRadius.large),
              bottomEnd: Radius.circular(AQRadius.large),
            ).resolve(Directionality.of(context)),
          ),
        ),
      ),
      const SizedBox(height: AQSpacing.x4),
      RoleReveal(
        index: 3,
        child: (MediaQuery.sizeOf(context).width < 380 || MediaQuery.textScalerOf(context).scale(1) > 1.3)
            ? Column(children: [
                Row(children: [indexItem('01', f.t('rh.arc.idx.profile'), profile), indexItem('02', f.t('rh.arc.idx.location'), profile)]),
                Row(children: [indexItem('03', f.t('rh.arc.idx.reviews'), reviews), indexItem('04', f.t('rh.arc.idx.contact'), () => context.push('/app/account/workspace/leads'))]),
              ])
            : Row(children: [
                indexItem('01', f.t('rh.arc.idx.profile'), profile),
                indexItem('02', f.t('rh.arc.idx.location'), profile),
                indexItem('03', f.t('rh.arc.idx.reviews'), reviews),
                indexItem('04', f.t('rh.arc.idx.contact'), () => context.push('/app/account/workspace/leads')),
              ]),
      ),
      RolePortfolioStrip(accent: accent),
      const SponsoredBannerSlot(audience: AdAudience.architecture),
      const RoleKpiStrip(role: HomeRole.architecture),
      Divider(color: c.hairline, height: AQSpacing.x6),
      RoleSection(f.t('rh.arc.practice'), action: f.t('rh.edit'), onAction: profile, accent: accent),
      org.when(
        loading: () => const DbSkeleton(height: 72),
        error: (_, _) => Text(f.t('common.networkError'), style: AQTypography.of(context, AQText.bodySmall, color: c.danger)),
        data: (x) {
          final bio = x?.bio.trim() ?? '';
          if (bio.isEmpty) return DbNotice(f.t('rh.bioEmpty'), icon: 'info', action: AQTextButton(label: f.t('rh.completeProfile'), color: c.accent, onPressed: profile));
          return Container(
            padding: const EdgeInsetsDirectional.only(start: AQSpacing.x4),
            decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: accent, width: 2))),
            child: Text(bio, style: AQTypography.of(context, AQText.titleMedium, soft: true).copyWith(fontStyle: FontStyle.italic)),
          );
        },
      ),
      RoleSection(f.t('rh.arc.essentials'), action: f.t('rh.arc.preview'), onAction: directory, accent: accent),
      RoleRow(leadingNumber: '01', label: f.t('rh.arc.identity'), value: o != null && o.name.isNotEmpty ? o.name : null, onTap: profile),
      RoleRow(leadingNumber: '02', label: f.t('rh.arc.bio'), onTap: profile),
      RoleRow(leadingNumber: '03', label: f.t('rh.arc.location'), value: o != null && o.locationLabel.isNotEmpty ? o.locationLabel : f.t('rh.notAdded'), onTap: profile),
      RoleRow(leadingNumber: '04', label: f.t('rh.arc.verification'), onTap: () => context.go('/verification')),
      RoleRow(leadingNumber: '05', label: f.t('rh.arc.reviews'), onTap: reviews),
      RoleRow(leadingNumber: '06', label: f.t('rh.arc.contact'), value: f.t('rh.unavailable'), onTap: () => context.push('/app/account/workspace/leads')),
      RoleRow(leadingNumber: '07', label: f.t('rh.leads.svc'), value: f.t('rh.view'), onTap: () => context.push('/workspace/requests')),
      const SizedBox(height: AQSpacing.x4),
      RoleReveal(
        index: 4,
        child: Semantics(
          button: true,
          focusable: true,
          onFocus: () {},
          label: '${f.t('rh.arc.preview')}. ${f.t('rh.arc.preview.b')}',
          excludeSemantics: true,
      onTap: directory,
          child: AQPressable(
            onTap: directory,
            child: Container(
              padding: const EdgeInsets.all(AQSpacing.x4),
              decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.t('rh.arc.preview').toUpperCase(), style: AQTypography.of(context, AQText.labelSmall, color: accent).copyWith(letterSpacing: 1.3)),
                    const SizedBox(height: 2),
                    Text(f.t('rh.arc.preview.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                  ]),
                ),
                AQIcon('chevron-right', size: 18, color: c.inkSoft, directional: true),
              ]),
            ),
          ),
        ),
      ),
      const SizedBox(height: AQSpacing.x3),
      DbNotice('${f.t('rh.arc.showcase')}: ${f.t('rh.arc.showcase.b')}', icon: 'lock'),
    ]);
  }
}

/// Interior & Exterior: a tactile, art-directed page. A room photograph, the real service type
/// (Interior / Exterior / Both) as a selector, a palette strip that is only a visual direction,
/// then profile essentials. No moodboard is saved and no showcase exists until the API does.
class InteriorHome extends ConsumerWidget {
  const InteriorHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final accent = roleAccent(context, HomeRole.interiorExterior);
    final org = ref.watch(dbMyOrgProvider);
    final o = org.valueOrNull;
    final service = o?.serviceType;
    void profile() => context.push('/app/account/workspace/profile');

    return RoleHomePage(children: [
      const RoleReveal(child: RoleHeader()),
      RoleReveal(
        index: 1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          RoleEyebrow(f.t('rh.int.eyebrow'), color: accent),
          const SizedBox(height: AQSpacing.x1),
          Semantics(header: true, child: Text(f.t('rh.int.title'), style: AQTypography.of(context, AQText.headlineLarge))),
        ]),
      ),
      const SizedBox(height: AQSpacing.x4),
      RoleReveal(
        index: 2,
        child: RolePhotoPanel(
          image: dbTypeImage(ProType.interiorExterior),
          kicker: f.t('rh.int.hero.k'),
          title: f.t('rh.int.hero'),
          body: f.t('rh.int.hero.b'),
          aspect: 1.6,
          alignment: Alignment.center,
        ),
      ),
      const SizedBox(height: AQSpacing.x3),
      RoleReveal(
        index: 3,
        child: org.isLoading && o == null
            ? const DbSkeleton(height: 112)
            : _ServicesCard(service: service, accent: accent, onEdit: profile),
      ),
      RolePortfolioStrip(accent: accent),
      const SponsoredBannerSlot(audience: AdAudience.interior),
      const RoleKpiStrip(role: HomeRole.interiorExterior),
      RoleSection(f.t('rh.int.language'), accent: accent),
      const _StudioStyles(),
      RoleSection(f.t('rh.int.essentials'), action: f.t('rh.manageProfile'), onAction: profile, accent: accent),
      RoleRow(label: f.t('rh.int.serviceType'), value: serviceSummary(f, service), onTap: profile),
      RoleRow(label: f.t('rh.int.bioLoc'), value: o != null && o.locationLabel.isNotEmpty ? o.locationLabel : f.t('rh.notAdded'), onTap: profile),
      RoleRow(label: f.t('rh.int.reviews'), onTap: () => context.push('/app/account/workspace/reviews')),
      RoleRow(label: f.t('rh.leads.svc'), value: f.t('rh.view'), onTap: () => context.push('/workspace/requests')),
      RoleRow(label: f.t('rh.verification'), value: f.t('rh.verification.sub'), onTap: () => context.go('/verification')),
      const SizedBox(height: AQSpacing.x4),
      DbNotice('${f.t('rh.int.showcase')}: ${f.t('rh.int.showcase.b')}', icon: 'lock'),
    ]);
  }
}

/// The studio's two services as the public profile has them: each is on or off, and "Interior + Exterior"
/// is only the description of both being on. Changing them happens in the profile editor, which sends the
/// change for review; this card always shows what is approved.
class _ServicesCard extends StatelessWidget {
  final InteriorExteriorServiceType? service;
  final Color accent;
  final VoidCallback onEdit;
  const _ServicesCard({required this.service, required this.accent, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final fl = serviceFlags(service);
    Widget chip(String icon, String label, bool on) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AQSpacing.x3, vertical: AQSpacing.x3),
        decoration: BoxDecoration(
          color: on ? accent.withValues(alpha: 0.14) : c.surfaceRaised,
          borderRadius: BorderRadius.circular(AQRadius.medium),
          border: Border.all(color: on ? accent : c.hairline, width: on ? 1.5 : 1),
        ),
        child: Row(children: [
          AQIcon(on ? 'check' : icon, size: 18, color: on ? accent : c.inkFaint),
          const SizedBox(width: AQSpacing.x2),
          Expanded(child: Text(label, style: AQTypography.of(context, AQText.labelLarge, color: on ? c.ink : c.inkSoft))),
        ]),
      ),
    );
    return Semantics(
      container: true,
      label: '${f.t('rh.int.service')}. ${serviceSummary(f, service)}',
      child: Container(
        padding: const EdgeInsets.all(AQSpacing.x4),
        decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(f.t('rh.int.service'), style: AQTypography.of(context, AQText.titleSmall))),
            AQTextButton(label: f.t('rh.edit'), trailingIcon: 'chevron-right', color: c.accentDeep, onPressed: onEdit),
          ]),
          const SizedBox(height: AQSpacing.x2),
          Row(children: [
            chip('interior', f.t('svc.interior.t'), fl.interior),
            const SizedBox(width: AQSpacing.x2),
            chip('architecture', f.t('svc.exterior.t'), fl.exterior),
          ]),
          const SizedBox(height: AQSpacing.x2),
          Text(service == null ? f.t('svc.none') : f.t('svc.offered', {'v': serviceSummary(f, service)}), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
        ]),
      ),
    );
  }
}

/// The studio's styles: real multi-select chips. The choice is held on this device in the preview and is
/// shown on the profile once saved; no client moodboard is stored or implied.
final studioStylesProvider = StateProvider<Set<String>>((ref) => {'contemporary', 'minimal'});

class _StudioStyles extends ConsumerStatefulWidget {
  const _StudioStyles();
  @override
  ConsumerState<_StudioStyles> createState() => _StudioStylesState();
}

class _StudioStylesState extends ConsumerState<_StudioStyles> {
  static const _keys = ['modern', 'minimal', 'contemporary', 'traditional', 'mediterranean', 'classic', 'industrial', 'organic'];
  bool _saved = true;
  late Set<String> _draft;
  @override
  void initState() {
    super.initState();
    _draft = {...ref.read(studioStylesProvider)};
  }

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(f.t('rh.int.language.b'), style: AQTypography.of(context, AQText.bodySmall, soft: true)),
      const SizedBox(height: AQSpacing.x3),
      Wrap(spacing: AQSpacing.x2, runSpacing: AQSpacing.x2, children: [
        for (final k in _keys)
          AQChoicePill(
            label: f.t('style.$k'),
            selected: _draft.contains(k),
            onTap: () => setState(() {
              _draft.contains(k) ? _draft.remove(k) : _draft.add(k);
              _saved = false;
            }),
          ),
      ]),
      const SizedBox(height: AQSpacing.x3),
      Row(children: [
        Expanded(
          child: Text(
            _saved ? f.t('style.saved') : f.t('style.unsaved', {'n': '${_draft.length}'}),
            style: AQTypography.of(context, AQText.labelMedium, color: _saved ? c.success : c.accentDeep),
          ),
        ),
        if (!_saved) ...[
          AQTextButton(label: f.t('common.cancel'), color: c.inkSoft, onPressed: () => setState(() {
                _draft = {...ref.read(studioStylesProvider)};
                _saved = true;
              })),
          AQTextButton(label: f.t('style.save'), color: c.accentDeep, onPressed: () {
            ref.read(studioStylesProvider.notifier).state = {..._draft};
            setState(() => _saved = true);
          }),
        ],
      ]),
    ]);
  }
}
