import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/aq/aq_primitives.dart';
import '../../core/aq/aq_tokens.dart';
import '../../core/aq/aq_typography.dart';
import '../../core/localization/flow_strings.dart';
import '../../data/api/account_api.dart' show meProvider;
import '../workspace/aq_home.dart' show aqImg;
import 'ad_models.dart';
import 'ad_repository.dart';

/// Height of the compact sponsored banner. Fixed, so a rotating ad never moves the page below it.
const double kSponsoredBannerHeight = 92;

/// The one customer-facing sponsored banner: a compact card (small picture, "Sponsored" label, a
/// short title and line, "Learn more"). It is mounted only on the User to Shop Home, between the
/// header and the hero. The admin console previews with this same widget, so the preview is the
/// real banner and not an imitation.
class SponsoredBannerView extends StatelessWidget {
  final List<SponsoredAd> ads;
  final int index;
  final void Function(SponsoredAd ad) onTap;
  const SponsoredBannerView({
    super.key,
    required this.ads,
    this.index = 0,
    required this.onTap,
  });

  Widget _thumb(SponsoredAd ad) {
    const fallback = ColoredBox(color: Color(0x22000000));
    if (ad.imageBytes != null) {
      return Image.memory(
        ad.imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final ref = ad.imageRef ?? '';
    if (ref.startsWith('https://')) {
      return Image.network(
        ref,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return aqImg(ref, cacheWidth: 300);
  }

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) return const SizedBox.shrink();
    final c = AQColors.of(context);
    final f = FlowStrings.of(context);
    var ad = ads[index.clamp(0, ads.length - 1)];
    final ar = kSampleCampaignsAr[ad.id];
    if (f.ar && ar != null && ad.headline == ar.$2) {
      ad = ad.copyWith(sponsor: ar.$1, headline: ar.$3, body: ar.$4, cta: ar.$5);
    }
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.2,
      child: Semantics(
        // One control for the whole banner, so the keyboard focus ring and a tap by a screen reader
        // cover the card and not just the chevron.
        container: true,
        button: true,
        focusable: true,
        onFocus: () {},
        onTap: () => onTap(ad),
        label: '${f.t('ad.sponsored')}: ${ad.sponsor}. ${ad.headline}. ${ad.cta}',
        excludeSemantics: true,
        child: SizedBox(
          height: kSponsoredBannerHeight,
          child: AnimatedSwitcher(
            duration: AQMotion.scaled(context, AQMotion.standard),
            switchInCurve: AQMotion.standardCurve,
            child: KeyedSubtree(
              key: ValueKey(ad.id),
              child: AQPressable(
                onTap: () => onTap(ad),
                child: LayoutBuilder(
                  builder: (context, box) {
                    // On the narrowest phones the sponsor name and the button word give way to the title.
                    final narrow = box.maxWidth < 350;
                    return Container(
                      padding: const EdgeInsets.all(AQSpacing.x2),
                      decoration: BoxDecoration(
                        color: c.surfaceRaised,
                        borderRadius: BorderRadius.circular(AQRadius.medium),
                        border: Border.all(color: c.hairline),
                      ),
                      child: Row(
                        children: [
                          ExcludeSemantics(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AQRadius.small,
                              ),
                              child: SizedBox(
                                width: 72,
                                height: double.infinity,
                                child: _thumb(ad),
                              ),
                            ),
                          ),
                          const SizedBox(width: AQSpacing.x3),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  narrow
                                      ? f.t('ad.sponsored').toUpperCase()
                                      : '${f.t('ad.sponsored').toUpperCase()} · ${ad.sponsor}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AQTypography.of(
                                    context,
                                    AQText.labelSmall,
                                    soft: true,
                                  ),
                                ),
                                Text(
                                  ad.headline,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AQTypography.of(
                                    context,
                                    AQText.titleMedium,
                                  ),
                                ),
                                if (ad.body.isNotEmpty)
                                  Text(
                                    ad.body,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AQTypography.of(
                                      context,
                                      AQText.bodySmall,
                                      soft: true,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AQSpacing.x2),
                          ExcludeSemantics(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 92),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!narrow)
                                    Flexible(
                                      child: Text(
                                        ad.cta,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AQTypography.of(
                                          context,
                                          AQText.labelMedium,
                                          color: c.accentDeep,
                                        ),
                                      ),
                                    ),
                                  AQIcon(
                                    'chevron-right',
                                    size: 16,
                                    color: c.accentDeep,
                                    directional: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Home slot. Signed-in people only; when there is nothing eligible, or the service cannot be
/// reached, it takes no space at all: there is never a broken banner. Ads rotate every five seconds
/// while the screen is visible.
class SponsoredBannerSlot extends ConsumerStatefulWidget {
  final AdPlacement placement;

  /// Which Home this is: the campaigns served are the ones aimed at this audience.
  final AdAudience audience;
  const SponsoredBannerSlot({
    super.key,
    this.placement = AdPlacement.homeTop,
    this.audience = AdAudience.customer,
  });
  @override
  ConsumerState<SponsoredBannerSlot> createState() =>
      _SponsoredBannerSlotState();
}

class _SponsoredBannerSlotState extends ConsumerState<SponsoredBannerSlot> {
  Timer? _timer;
  int _index = 0;
  String? _counted;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<SponsoredAd> _ads() {
    if (!ref.watch(meProvider).hasValue) return const <SponsoredAd>[];
    return ref
            .watch(servedAdsProvider((widget.placement, widget.audience)))
            .valueOrNull ??
        const <SponsoredAd>[];
  }

  void _sync(List<SponsoredAd> ads) {
    if (ads.length < 2) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _timer ??= Timer.periodic(kAdRotation, (_) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      final n = _ads().length;
      if (n > 1) setState(() => _index = (_index + 1) % n);
    });
  }

  void _impression(SponsoredAd ad) {
    if (_counted == ad.id) return;
    _counted = ad.id;
    ref
        .read(adRepositoryProvider)
        .recordEvent(ad.id, AdEventKind.impression)
        .catchError((_) {});
  }

  Future<void> _open(SponsoredAd ad) async {
    ref
        .read(adRepositoryProvider)
        .recordEvent(ad.id, AdEventKind.tap)
        .catchError((_) {});
    final d = ad.destination.trim();
    final route = adInAppRoute(d);
    if (route != null) {
      if (mounted) context.push(route);
      return;
    }
    final u = Uri.tryParse(d);
    if (u != null && u.scheme == 'https') {
      try {
        await launchUrl(u, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ads = _ads();
    _sync(ads);
    if (ads.isEmpty) return const SizedBox.shrink();
    final i = _index % ads.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _impression(ads[i]);
    });
    return Padding(
      padding: const EdgeInsets.only(top: AQSpacing.x3),
      child: SponsoredBannerView(ads: ads, index: i, onTap: _open),
    );
  }
}
