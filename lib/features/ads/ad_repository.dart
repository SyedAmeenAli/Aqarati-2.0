import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../core/config/qa_faults.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import 'ad_models.dart';

enum AdEventKind { impression, tap }

/// What the customer app needs: only approved, in-schedule banners for a placement (`GET /ads`),
/// and best-effort impression / tap events (`POST /ads/:id/events`). A failure here must never be
/// visible to the customer: no banner is shown instead of a broken one.
abstract class AdRepository {
  Future<List<SponsoredAd>> served(
    AdPlacement placement, {
    AdAudience audience = AdAudience.customer,
  });
  Future<void> recordEvent(String adId, AdEventKind kind);
}

class UnavailableAdRepository implements AdRepository {
  const UnavailableAdRepository();
  @override
  Future<List<SponsoredAd>> served(
    AdPlacement placement, {
    AdAudience audience = AdAudience.customer,
  }) async => throw const ApiException(ApiErrorCode.network);
  @override
  Future<void> recordEvent(String adId, AdEventKind kind) async =>
      throw const ApiException(ApiErrorCode.network);
}

/// What the admin console needs (`GET / POST / PATCH /admin/ads`). The service enforces roles,
/// review and scheduling; the console only reflects what it answers.
abstract class AdAdminRepository {
  Future<List<SponsoredAd>> list();
  Future<SponsoredAd?> get(String id);
  Future<SponsoredAd> create(AdDraft draft);
  Future<SponsoredAd> update(String id, AdDraft draft);
  Future<SponsoredAd> submitForReview(String id);
  Future<SponsoredAd> pause(String id);
  Future<SponsoredAd> resume(String id);

  /// Sets the display order of the given ads (first is shown first).
  Future<List<SponsoredAd>> reorder(List<String> idsInOrder);

  /// A reviewer's decision on a banner that waits for review: approved, resubmissionRequired or
  /// rejected. The two negative outcomes carry a reason code and a note.
  Future<SponsoredAd> decide(
    String id, {
    required AdStatus outcome,
    String? reasonCode,
    String note = '',
  });
}

/// DEMO ONLY: one in-memory store used by both the customer reads and the admin writes, so the
/// console and the preview agree. Starts empty; nothing is invented.
class DemoAdRepository implements AdRepository, AdAdminRepository {
  DemoAdRepository({
    this.latency = const Duration(milliseconds: 250),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration latency;
  final DateTime Function() _clock;
  final List<SponsoredAd> _items = [];
  int _seq = 0;

  /// Test and QA hook: the next call fails with this error.
  Object? debugNextError;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (qaCallsFail()) throw const ApiException(ApiErrorCode.network);
    final err = debugNextError;
    if (err != null) {
      debugNextError = null;
      throw err;
    }
  }

  SponsoredAd _find(String id) {
    final i = _items.indexWhere((a) => a.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    return _items[i];
  }

  void _put(SponsoredAd a) =>
      _items[_items.indexWhere((x) => x.id == a.id)] = a;

  @override
  Future<List<SponsoredAd>> served(
    AdPlacement placement, {
    AdAudience audience = AdAudience.customer,
  }) async {
    await _lag();
    final now = _clock();
    final list =
        _items
            .where(
              (a) =>
                  a.placement == placement &&
                  a.audiences.contains(audience) &&
                  a.servableAt(now),
            )
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));
    return List.unmodifiable(list);
  }

  @override
  Future<void> recordEvent(String adId, AdEventKind kind) async {}

  @override
  Future<List<SponsoredAd>> list() async {
    await _lag();
    final list = [..._items]
      ..sort(
        (a, b) => a.placement == b.placement
            ? a.order.compareTo(b.order)
            : a.placement.index.compareTo(b.placement.index),
      );
    return List.unmodifiable(list);
  }

  @override
  Future<SponsoredAd?> get(String id) async {
    await _lag();
    return _items.where((a) => a.id == id).firstOrNull;
  }

  @override
  Future<SponsoredAd> create(AdDraft d) async {
    await _lag();
    if (validateAd(d).isNotEmpty) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    final a = SponsoredAd(
      id: 'ad${++_seq}',
      sponsor: d.sponsor.trim(),
      headline: d.headline.trim(),
      body: d.body.trim(),
      cta: d.cta.trim(),
      destination: d.destination.trim(),
      imageRef: d.imageRef,
      imageBytes: d.imageBytes,
      imageName: d.imageName,
      placement: d.placement,
      audiences: d.audiences,
      status: AdStatus.draft,
      startsAt: d.startsAt,
      endsAt: d.endsAt,
      order: _items.where((x) => x.placement == d.placement).length,
      updatedAt: _clock(),
    );
    _items.add(a);
    return a;
  }

  @override
  Future<SponsoredAd> update(String id, AdDraft d) async {
    await _lag();
    final old = _find(id);
    if (!old.canEdit) throw const ApiException(ApiErrorCode.conflict);
    if (validateAd(d).isNotEmpty) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    // A material edit to an approved banner goes back to review: it is not served meanwhile.
    final next = SponsoredAd(
      id: old.id,
      sponsor: d.sponsor.trim(),
      headline: d.headline.trim(),
      body: d.body.trim(),
      cta: d.cta.trim(),
      destination: d.destination.trim(),
      imageRef: d.imageRef ?? (d.imageBytes == null ? old.imageRef : null),
      imageBytes: d.imageBytes ?? (d.imageRef == null ? old.imageBytes : null),
      imageName: d.imageName ?? old.imageName,
      placement: d.placement,
      audiences: d.audiences,
      status:
          old.status == AdStatus.approved ||
              old.status == AdStatus.paused ||
              old.status == AdStatus.rejected
          ? AdStatus.draft
          : old.status,
      startsAt: d.startsAt,
      endsAt: d.endsAt,
      order: old.order,
      updatedAt: _clock(),
    );
    _put(next);
    return next;
  }

  @override
  Future<SponsoredAd> submitForReview(String id) async {
    await _lag();
    final a = _find(id);
    if (!a.canSubmit) throw const ApiException(ApiErrorCode.conflict);
    final n = a.copyWith(
      status: AdStatus.pendingVerification,
      updatedAt: _clock(),
    );
    _put(n);
    return n;
  }

  @override
  Future<SponsoredAd> pause(String id) async {
    await _lag();
    final a = _find(id);
    if (!a.canPause) throw const ApiException(ApiErrorCode.conflict);
    final n = a.copyWith(status: AdStatus.paused, updatedAt: _clock());
    _put(n);
    return n;
  }

  @override
  Future<SponsoredAd> resume(String id) async {
    await _lag();
    final a = _find(id);
    if (!a.canResume) throw const ApiException(ApiErrorCode.conflict);
    final n = a.copyWith(status: AdStatus.approved, updatedAt: _clock());
    _put(n);
    return n;
  }

  @override
  Future<List<SponsoredAd>> reorder(List<String> idsInOrder) async {
    await _lag();
    for (var i = 0; i < idsInOrder.length; i++) {
      _put(_find(idsInOrder[i]).copyWith(order: i));
    }
    return list();
  }

  @override
  Future<SponsoredAd> decide(
    String id, {
    required AdStatus outcome,
    String? reasonCode,
    String note = '',
  }) async {
    await _lag();
    final a = _find(id);
    if (a.status != AdStatus.pendingVerification) {
      throw const ApiException(ApiErrorCode.conflict);
    }
    if (outcome != AdStatus.approved &&
        outcome != AdStatus.resubmissionRequired &&
        outcome != AdStatus.rejected) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    final n = a.copyWith(
      status: outcome,
      feedback: outcome == AdStatus.approved
          ? null
          : (note.isNotEmpty ? note : reasonCode),
      updatedAt: _clock(),
    );
    _put(n);
    return n;
  }

  /// QA / review only: a reviewer's decision on a banner (banners are approved in the review queue,
  /// never by the person who edits them in this screen).
  void debugDecide(String id, AdStatus status, {String? feedback}) => _put(
    _find(id).copyWith(status: status, feedback: feedback, updatedAt: _clock()),
  );

  /// QA / tests: adds a banner directly in any state.
  SponsoredAd debugAdd(
    AdDraft d, {
    AdStatus status = AdStatus.approved,
    String? id,
  }) {
    final a = SponsoredAd(
      id: id ?? 'ad${++_seq}',
      sponsor: d.sponsor,
      headline: d.headline,
      body: d.body,
      cta: d.cta,
      destination: d.destination,
      imageRef: d.imageRef,
      imageBytes: d.imageBytes,
      imageName: d.imageName,
      placement: d.placement,
      audiences: d.audiences,
      status: status,
      startsAt: d.startsAt,
      endsAt: d.endsAt,
      order: _items.where((x) => x.placement == d.placement).length,
      updatedAt: _clock(),
    );
    _items.add(a);
    return a;
  }
}

/// Fictional sample campaigns, one per Home audience, so every Home shows a banner in the
/// prototype. They are labelled "Sponsored"; the sponsors are invented and no advertising
/// agreement or payment exists. Order is fixed, so the demo is deterministic.
const kSampleCampaigns =
    <(String, AdAudience, String, String, String, String, String, String)>[
      ('s1', AdAudience.customer, 'Al Mouj Waterfront (sample)', 'Waterfront residences, now previewing', 'A sample developer campaign', 'View homes', '/properties?cat=residential', 'assets/properties/p1/02_Infinity_pool_overlooking_marina.jpg'),
      ('s2', AdAudience.agent, 'Qurum Heights (sample)', 'Pre-launch units for your clients', 'Sample project for agents', 'See homes', '/properties?cat=residential', 'assets/location/11_Muscat_skyline_and_mountains.jpg'),
      ('s3', AdAudience.developer, 'Gulf Materials (sample)', 'Bulk pricing for project developers', 'A sample supplier campaign', 'Find builders', '/app/explore/build/results?cat=construction', 'assets/businesses/b2/05_Construction_site_with_tower_crane.jpg'),
      ('s4', AdAudience.construction, 'Plant Hire Oman (sample)', 'Cranes and plant, ready in Muscat', 'A sample equipment campaign', 'Browse', '/professionals?cat=maintenance', 'assets/businesses/b2/03_Construction_equipment_at_buildi.jpg'),
      ('s5', AdAudience.architecture, 'Studio Light (sample)', 'Visualisation tools for architects', 'A sample software campaign', 'Learn more', '/app/explore/build/results?cat=architecture', 'assets/businesses/b1/05_Contemporary_architectural_facad.jpg'),
      ('s6', AdAudience.interior, 'Dar Fabrics (sample)', 'Linen, stone and timber samples', 'A sample materials campaign', 'Explore', '/app/explore/build/results?cat=interiorExterior', 'assets/businesses/b3/06_Styled_bedroom_interior_photography.jpg'),
    ];

/// Arabic copy for the sample campaigns (id to sponsor, headline, line, button). Draft Arabic text that
/// needs native review. Used only while a campaign still carries its original English headline.
const kSampleCampaignsAr = <String, (String, String, String, String, String)>{
  's1': ('واجهة المويج (نموذج)', 'Waterfront residences, now previewing', 'مساكن على الواجهة البحرية، معروضة الآن', 'حملة مطوّر تجريبية', 'عرض المنازل'),
  's2': ('مرتفعات القرم (نموذج)', 'Pre-launch units for your clients', 'وحدات ما قبل الإطلاق لعملائك', 'مشروع تجريبي للوسطاء', 'عرض المنازل'),
  's3': ('مواد الخليج (نموذج)', 'Bulk pricing for project developers', 'أسعار الجملة لمطوري المشاريع', 'حملة مورّد تجريبية', 'ابحث عن مقاولين'),
  's4': ('تأجير المعدات عُمان (نموذج)', 'Cranes and plant, ready in Muscat', 'رافعات ومعدات جاهزة في مسقط', 'حملة معدات تجريبية', 'تصفّح'),
  's5': ('ستوديو لايت (نموذج)', 'Visualisation tools for architects', 'أدوات تصوّر للمعماريين', 'حملة برمجيات تجريبية', 'اعرف المزيد'),
  's6': ('دار الأقمشة (نموذج)', 'Linen, stone and timber samples', 'عينات الكتان والحجر والخشب', 'حملة مواد تجريبية', 'استكشف'),
};

/// Adds the sample campaigns (approved, always in schedule) and two more so the console has
/// something to filter: one paused, one waiting for review.
void seedSampleCampaigns(DemoAdRepository repo) {
  for (final (id, aud, sponsor, headline, body, cta, dest, image)
      in kSampleCampaigns) {
    repo.debugAdd(
      AdDraft(
        sponsor: sponsor,
        headline: headline,
        body: body,
        cta: cta,
        destination: dest,
        imageRef: image,
        audiences: {aud},
      ),
      id: id,
    );
  }
  repo.debugAdd(
    const AdDraft(
      sponsor: 'Muscat Furnishings (sample)',
      headline: 'Autumn showroom event',
      body: 'Paused sample campaign',
      cta: 'Visit',
      destination: '/professionals?cat=maintenance',
      imageRef: 'assets/businesses/b3/04_Reading_and_work_nook.jpg',
      audiences: {AdAudience.customer, AdAudience.interior},
    ),
    status: AdStatus.paused,
    id: 's7',
  );
  repo.debugAdd(
    const AdDraft(
      sponsor: 'Seeb Land Fund (sample)',
      headline: 'Plots near the new road',
      body: 'Sample campaign waiting for review',
      cta: 'See plots',
      destination: '/properties?cat=agriculture',
      imageRef: 'assets/location/12_Nizwa_Fort_and_mountains_landscape.jpg',
      audiences: {AdAudience.customer, AdAudience.agent},
    ),
    status: AdStatus.pendingVerification,
    id: 's8',
  );
}

final adRepositoryProvider = Provider<AdRepository>((ref) {
  if (!kUseDemoBackend) return const UnavailableAdRepository();
  final repo = DemoAdRepository();
  seedSampleCampaigns(repo);
  return repo;
});
final servedAdsProvider = FutureProvider.autoDispose
    .family<List<SponsoredAd>, (AdPlacement, AdAudience)>(
      (ref, key) =>
          ref.watch(adRepositoryProvider).served(key.$1, audience: key.$2),
    );
