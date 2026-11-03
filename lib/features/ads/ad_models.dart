/// Sponsored banners. Rules from architecture v2.6 (ads module): banners pass review before they can
/// be served, are served only inside their placement and schedule, are labelled "Sponsored", and are
/// never shown on signup, verification, document, account or admin screens. Creatives are JPG or PNG,
/// at most 5 MB, and the schedule must have start before end.
library;

import 'dart:typed_data';

/// Wire names are `home_top` and `results_in_feed`.
enum AdPlacement { homeTop, resultsInFeed }

/// Who a banner is for: the Home screen it may appear on. One banner can target several audiences.
/// (The six public roles: User to Shop, Real Estate Agent, and the four professional kinds.)
enum AdAudience { customer, agent, developer, construction, architecture, interior }

/// Items share the verification state machine (draft, pending_verification, approved,
/// resubmission_required, rejected). [paused] and [expired] come from the ad events the module emits
/// (`ad.paused`, `ad.expired`).
enum AdStatus {
  draft,
  pendingVerification,
  approved,
  resubmissionRequired,
  rejected,
  paused,
  expired,
}

/// How long each banner stays before the next one: the approved rotation interval.
const kAdRotation = Duration(seconds: 5);
const kAdMaxImageBytes = 5 * 1024 * 1024;

class SponsoredAd {
  final String id;
  final String sponsor, headline, body, cta;

  /// An https address, or an app route that starts with `/`.
  final String destination;

  /// Where the creative lives: an https address, or a bundled asset path (demo and previews).
  final String? imageRef;

  /// A creative picked on this device and not uploaded yet (previews and drafts only).
  final Uint8List? imageBytes;
  final String? imageName;
  final AdPlacement placement;

  /// The Home screens this banner may be served to. Never empty.
  final Set<AdAudience> audiences;
  final AdStatus status;
  final DateTime? startsAt, endsAt;

  /// Position inside the placement, lowest first.
  final int order;

  /// Reviewer feedback for resubmission_required / rejected, when the service returns it.
  final String? feedback;
  final DateTime updatedAt;
  const SponsoredAd({
    required this.id,
    required this.sponsor,
    required this.headline,
    this.body = '',
    required this.cta,
    required this.destination,
    this.imageRef,
    this.imageBytes,
    this.imageName,
    this.placement = AdPlacement.homeTop,
    this.audiences = const {AdAudience.customer},
    this.status = AdStatus.draft,
    this.startsAt,
    this.endsAt,
    this.order = 0,
    this.feedback,
    required this.updatedAt,
  });

  /// Eligible to be shown at [now]: approved and inside its schedule.
  bool servableAt(DateTime now) =>
      status == AdStatus.approved &&
      (startsAt == null || !now.isBefore(startsAt!)) &&
      (endsAt == null || !now.isAfter(endsAt!));

  bool get canEdit => status != AdStatus.expired;
  bool get canSubmit =>
      status == AdStatus.draft || status == AdStatus.resubmissionRequired;
  bool get canPause => status == AdStatus.approved;
  bool get canResume => status == AdStatus.paused;

  SponsoredAd copyWith({
    String? sponsor,
    String? headline,
    String? body,
    String? cta,
    AdStatus? status,
    int? order,
    String? feedback,
    DateTime? updatedAt,
  }) => SponsoredAd(
    id: id,
    sponsor: sponsor ?? this.sponsor,
    headline: headline ?? this.headline,
    body: body ?? this.body,
    cta: cta ?? this.cta,
    destination: destination,
    imageRef: imageRef,
    imageBytes: imageBytes,
    imageName: imageName,
    placement: placement,
    audiences: audiences,
    status: status ?? this.status,
    startsAt: startsAt,
    endsAt: endsAt,
    order: order ?? this.order,
    feedback: feedback ?? this.feedback,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// What the create / edit form submits.
class AdDraft {
  final String sponsor, headline, body, cta, destination;
  final String? imageRef;
  final Uint8List? imageBytes;
  final String? imageName;
  final AdPlacement placement;
  final Set<AdAudience> audiences;
  final DateTime? startsAt, endsAt;
  const AdDraft({
    required this.sponsor,
    required this.headline,
    this.body = '',
    required this.cta,
    required this.destination,
    this.imageRef,
    this.imageBytes,
    this.imageName,
    this.placement = AdPlacement.homeTop,
    this.audiences = const {AdAudience.customer},
    this.startsAt,
    this.endsAt,
  });
}

bool _isJpgOrPng(Uint8List b) =>
    b.length >= 4 &&
    ((b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) ||
        (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47));

bool destinationValid(String d) {
  final t = d.trim();
  if (t.startsWith('/')) return t.length > 1 && !t.contains(' ');
  final u = Uri.tryParse(t);
  return u != null &&
      u.scheme == 'https' &&
      u.host.contains('.') &&
      !t.contains(' ');
}

/// Field-level problems as string keys ([field] -> message key). Empty means the draft is valid.
Map<String, String> validateAd(AdDraft d) {
  final e = <String, String>{};
  if (d.sponsor.trim().isEmpty) e['sponsor'] = 'adm.err.sponsor';
  if (d.headline.trim().isEmpty) e['headline'] = 'adm.err.headline';
  if (d.cta.trim().isEmpty) e['cta'] = 'adm.err.cta';
  if (d.audiences.isEmpty) e['audience'] = 'adm.err.audience';
  if (!destinationValid(d.destination)) {
    e['destination'] = 'adm.err.destination';
  }
  final bytes = d.imageBytes;
  if (bytes == null && (d.imageRef == null || d.imageRef!.isEmpty)) {
    e['image'] = 'adm.err.image';
  } else if (bytes != null) {
    if (!_isJpgOrPng(bytes)) {
      e['image'] = 'adm.err.imageType';
    } else if (bytes.length > kAdMaxImageBytes) {
      e['image'] = 'adm.err.imageSize';
    }
  }
  if (d.startsAt != null &&
      d.endsAt != null &&
      d.startsAt!.isAfter(d.endsAt!)) {
    e['schedule'] = 'adm.err.schedule';
  }
  return e;
}

/// App routes a banner may point at. A destination that is a path but not one of these is replaced
/// by [kAdFallbackRoute] when tapped, so a mistyped campaign never lands on an error page.
const kAdKnownRoutePrefixes = <String>[
  '/app/',
  '/properties',
  '/property/',
  '/professionals',
  '/business/',
  '/calculators',
  '/sell',
  '/saved',
  '/search',
  '/map',
  '/agent',
  '/pro',
];
const kAdFallbackRoute = '/app/explore';

/// The route a tap on [destination] should open, or null for an external https address.
String? adInAppRoute(String destination) {
  final d = destination.trim();
  if (!d.startsWith('/')) return null;
  return kAdKnownRoutePrefixes.any(d.startsWith) ? d : kAdFallbackRoute;
}
