import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../devbuild/db_models.dart';
import '../media/aq_media.dart';
import '../entry/widgets/entry_common.dart' show MasterLogo;
import '../devbuild/db_repository.dart';
import '../devbuild/db_widgets.dart' show DbSkeleton, dbTypeImage;
import 'role_home_model.dart';
import 'role_home_widgets.dart';
import '../ads/ad_models.dart' show AdAudience;
import '../ads/sponsored_banner.dart';
import '../analytics/analytics_screens.dart' show RoleKpiStrip;
import '../../core/domain/account_models.dart' show GrantState;
import '../../data/api/account_api.dart' show meProvider;

/// Construction: industrial and trust-first. A site photograph leads, then the company
/// profile and four "essentials". It is a company-profile home, not a project dashboard:
/// no tenders, bids, job pipeline or project tools exist for this role.
class ConstructionHome extends ConsumerWidget {
  const ConstructionHome({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = FlowStrings.of(context);
    final accent = roleAccent(context, HomeRole.construction);
    final org = ref.watch(dbMyOrgProvider);
    final profileGap = org.valueOrNull != null && (org.valueOrNull!.locationLabel.isEmpty || org.valueOrNull!.bio.isEmpty);
    void profile() => context.push('/app/account/workspace/profile');
    // Two different conditions, never merged: the account being under review (set by the review
    // process, never by this screen) and the public profile still missing details.
    final awaitingReview = ref.watch(meProvider).valueOrNull?.grant == GrantState.pendingVerification;

    final orgOk = org.valueOrNull != null;
    return RoleHomePage(children: [
      // A compact header: logo, role label and a short title. The hero below stays a card, not the page.
      RoleReveal(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AQSpacing.x2),
          child: Row(children: [
            Consumer(builder: (c, ref, _) => ref.watch(businessLogoProvider) == null ? const MasterLogo(width: 56) : const AQBusinessLogo(size: 56)),
            const SizedBox(width: AQSpacing.x3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                RoleEyebrow(f.t('rh.con.eyebrow'), color: accent),
                Semantics(header: true, child: Text(f.t('rh.con.title'), maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleLarge))),
              ]),
            ),
          ]),
        ),
      ),
      const SizedBox(height: AQSpacing.x2),
      RoleReveal(
        index: 2,
        child: RolePhotoPanel(
          image: ref.watch(businessCoverProvider) != null ? registerAqMedia(ref.watch(businessCoverProvider)!) : dbTypeImage(ProType.construction),
          kicker: f.t(ProType.construction.key).toUpperCase(),
          title: f.t('rh.con.hero'),
          aspect: 1.9,
          alignment: Alignment.topCenter,
          actions: [RolePhotoButton(label: f.t('rh.manageProfile'), icon: 'edit', onTap: profile)],
        ),
      ),
      const SizedBox(height: AQSpacing.x3),
      RoleReveal(
        index: 3,
        child: _ProfileStatusCard(
          name: org.valueOrNull?.name ?? '',
          loading: org.isLoading && !org.hasValue,
          failed: org.hasError && !org.hasValue,
          awaitingReview: awaitingReview,
          profileGap: profileGap,
          accent: accent,
          onTap: profile,
        ),
      ),
      const SizedBox(height: AQSpacing.x4),
      const RoleKpiStrip(role: HomeRole.construction),
      // One sponsored banner, after the company's own information so it never competes with it.
      const SponsoredBannerSlot(audience: AdAudience.construction),
      RoleSection(f.t('rh.con.essentials'), action: f.t('rh.manageProfile'), onAction: profile, accent: accent),
      _EssentialsGrid(children: [
        RoleEssentialCard(number: '01', icon: 'account', label: f.t('rh.con.identity'), sub: f.t('rh.con.identity.s'), accent: accent, onTap: profile, status: orgOk ? (org.valueOrNull!.bio.isEmpty ? f.t('rh.ess.addDetails') : f.t('rh.ess.complete')) : null, statusOk: orgOk && org.valueOrNull!.bio.isNotEmpty),
        RoleEssentialCard(number: '02', icon: 'pin', label: f.t('rh.con.presence'), sub: f.t('rh.con.presence.s'), accent: accent, onTap: profile, status: orgOk ? (org.valueOrNull!.locationLabel.isEmpty ? f.t('rh.ess.addDetails') : f.t('rh.ess.complete')) : null, statusOk: orgOk && org.valueOrNull!.locationLabel.isNotEmpty),
        RoleEssentialCard(number: '03', icon: 'explore', label: f.t('rh.con.directory'), sub: f.t('rh.con.directory.s'), accent: accent, onTap: () => context.go('/app/explore/build/results?cat=construction')),
        RoleEssentialCard(number: '04', icon: 'star', label: f.t('rh.con.reputation'), sub: f.t('rh.con.reputation.s'), accent: accent, onTap: () => context.push('/app/account/workspace/reviews')),
      ]),
      RoleSection(f.t('rh.con.info'), action: f.t('rh.edit'), onAction: profile, accent: accent),
      RoleRow(label: f.t('rh.con.cr'), value: f.t('rh.con.cr.s'), onTap: () => context.push('/verification/details')),
      RoleRow(label: f.t('rh.con.office'), value: f.t('rh.view'), onTap: profile),
      RoleRow(label: f.t('rh.leads.svc'), value: f.t('rh.view'), onTap: () => context.push('/workspace/requests')),
      RoleRow(label: f.t('rh.contact'), value: f.t('rh.unavailable'), onTap: () => context.push('/app/account/workspace/leads')),
    ]);
  }
}

/// A 2 x 2 grid of essentials on a phone (one column only at very large text), wider on a tablet.
class _EssentialsGrid extends StatelessWidget {
  final List<Widget> children;
  const _EssentialsGrid({required this.children});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final large = MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final cols = large && box.maxWidth < 640 ? 1 : (box.maxWidth >= 900 ? 4 : 2);
        const gap = AQSpacing.x3;
        return Column(children: [
          for (var i = 0; i < children.length; i += cols) ...[
            if (i > 0) const SizedBox(height: gap),
            IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                for (var j = 0; j < cols; j++) ...[
                  if (j > 0) const SizedBox(width: gap),
                  Expanded(child: i + j < children.length ? children[i + j] : const SizedBox.shrink()),
                ],
              ]),
            ),
          ],
        ]);
      });
}

/// The company-profile status on Home. The name leads; the state line says what is true
/// (awaiting review, profile incomplete, or profile complete) and the action matches it. It fits
/// the content width at any text size: the label wraps, the action sits under it when needed.
class _ProfileStatusCard extends StatelessWidget {
  final String name;
  final bool loading, failed, awaitingReview, profileGap;
  final Color accent;
  final VoidCallback onTap;
  const _ProfileStatusCard({required this.name, required this.loading, required this.failed, required this.awaitingReview, required this.profileGap, required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final f = FlowStrings.of(context);
    final c = AQColors.of(context);
    final (state, hint, action, tone) = awaitingReview
        ? (f.t('rh.con.st.review'), f.t('rh.con.st.review.b'), f.t('rh.view'), c.warning)
        : profileGap
            ? (f.t('rh.con.st.gap'), f.t('rh.con.st.gap.b'), f.t('rh.complete'), c.warning)
            : (f.t('rh.con.st.ok'), f.t('rh.con.profile.sub'), f.t('rh.view'), c.success);
    final title = name.isNotEmpty ? name : f.t('rh.con.profile');
    return Semantics(
      button: true,
      focusable: true,
      onFocus: () {},
      label: '$title. $state. $hint',
      excludeSemantics: true,
      onTap: onTap,
      child: AQPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(AQSpacing.x3),
          decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: BorderRadius.circular(AQRadius.medium), border: Border.all(color: c.hairline)),
          child: loading
              ? const DbSkeleton(height: 56)
              : failed
                  ? Text(f.t('common.networkError'), style: AQTypography.of(context, AQText.bodySmall, color: c.danger))
                  : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(color: accent.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(AQRadius.small)),
                        child: Center(child: AQIcon('construction', size: 22, color: accent)),
                      ),
                      const SizedBox(width: AQSpacing.x3),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AQTypography.of(context, AQText.titleMedium)),
                          const SizedBox(height: 4),
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Flexible(child: Text(state, style: AQTypography.of(context, AQText.labelMedium, color: c.ink))),
                          ]),
                          const SizedBox(height: 2),
                          Text(hint, style: AQTypography.of(context, AQText.bodySmall, soft: true)),
                          const SizedBox(height: AQSpacing.x2),
                          RoleChip(action, color: accent),
                        ]),
                      ),
                    ]),
        ),
      ),
    );
  }
}
