import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/backend_mode.dart';
import '../core/config/qa_faults.dart';
import '../data/api/account_api.dart' show ApiErrorCode, ApiException;
import '../data/models/enums.dart';
import '../features/ads/ad_models.dart';
import '../features/ads/ad_repository.dart';
import '../features/ebroker/ebroker_models.dart';
import '../features/ebroker/ebroker_repository.dart';
import 'admin_models.dart';
import 'admin_l10n.dart';

// ------------------------------------------------------------------ contracts

/// Admin sign-in: separate credentials, then a one-time code (TOTP), then a role. The service owns
/// all of it; the console only moves between the stages it reports.
abstract class AdminAuthRepository {
  Future<void> signIn(String email, String password);
  Future<AdminSession> verifyTotp(String code);

  /// Step-up re-authentication before a decision.
  Future<void> reauthenticate(String code);
  Future<void> signOut();
}

abstract class VerificationRepository {
  Future<List<VerificationItem>> list();
  Future<VerificationItem?> get(String id);

  /// Takes the 30-minute review lock. Throws [AdminLockedException] when someone else holds it.
  Future<VerificationItem> claim(String id);
  Future<void> release(String id);
  Future<VerificationItem> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  });
}

abstract class ModerationRepository {
  Future<List<ListingSubmission>> list();
  Future<ListingSubmission?> get(String id);
  Future<ListingSubmission> claim(String id);
  Future<void> release(String id);
  Future<ListingSubmission> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  });
}

class UnavailableAdminAuthRepository implements AdminAuthRepository {
  const UnavailableAdminAuthRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<void> signIn(String email, String password) async => _no();
  @override
  Future<AdminSession> verifyTotp(String code) async => _no();
  @override
  Future<void> reauthenticate(String code) async => _no();
  @override
  Future<void> signOut() async {}
}

class UnavailableVerificationRepository implements VerificationRepository {
  const UnavailableVerificationRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<VerificationItem>> list() async => _no();
  @override
  Future<VerificationItem?> get(String id) async => _no();
  @override
  Future<VerificationItem> claim(String id) async => _no();
  @override
  Future<void> release(String id) async => _no();
  @override
  Future<VerificationItem> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  }) async => _no();
}

class UnavailableModerationRepository implements ModerationRepository {
  const UnavailableModerationRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<ListingSubmission>> list() async => _no();
  @override
  Future<ListingSubmission?> get(String id) async => _no();
  @override
  Future<ListingSubmission> claim(String id) async => _no();
  @override
  Future<void> release(String id) async => _no();
  @override
  Future<ListingSubmission> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  }) async => _no();
}

class UnavailableAdAdminRepository implements AdAdminRepository {
  const UnavailableAdAdminRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<SponsoredAd>> list() async => _no();
  @override
  Future<SponsoredAd?> get(String id) async => _no();
  @override
  Future<SponsoredAd> create(AdDraft draft) async => _no();
  @override
  Future<SponsoredAd> update(String id, AdDraft draft) async => _no();
  @override
  Future<SponsoredAd> submitForReview(String id) async => _no();
  @override
  Future<SponsoredAd> pause(String id) async => _no();
  @override
  Future<SponsoredAd> resume(String id) async => _no();
  @override
  Future<List<SponsoredAd>> reorder(List<String> idsInOrder) async => _no();
  @override
  Future<SponsoredAd> decide(
    String id, {
    required AdStatus outcome,
    String? reasonCode,
    String note = '',
  }) async => _no();
}

// ------------------------------------------------------------------ demo

/// DEMO ONLY: one in-memory console backend. It starts empty. "Demo records" are added only by an
/// explicit button, are labelled as demo, and contain no real documents. The role rules here mirror
/// what the service is documented to enforce; they are not a substitute for it.
class DemoAdminStore implements AdminAuthRepository, VerificationRepository {
  DemoAdminStore({
    this.latency = const Duration(milliseconds: 250),
    DateTime Function()? clock,
    DemoAdRepository? ads,
  }) : _clock = clock ?? DateTime.now,
       ads = ads ?? DemoAdRepository(latency: latency, clock: clock);
  final Duration latency;
  final DateTime Function() _clock;
  final DemoAdRepository ads;

  static const demoPassword = 'demo-admin';
  static const demoCode = '123456';
  static const accounts = <String, AdminSession>{
    'reviewer@demo.test': AdminSession(
      id: 'adm1',
      name: 'Demo Reviewer',
      role: AdminRole.reviewer,
    ),
    'senior@demo.test': AdminSession(
      id: 'adm2',
      name: 'Demo Senior Reviewer',
      role: AdminRole.seniorReviewer,
    ),
    'super@demo.test': AdminSession(
      id: 'adm3',
      name: 'Demo Super Admin',
      role: AdminRole.superAdmin,
    ),
    'auditor@demo.test': AdminSession(
      id: 'adm4',
      name: 'Demo Auditor',
      role: AdminRole.auditor,
    ),
  };

  AdminSession? _pending, _session;
  bool _expired = false;
  final List<VerificationItem> _verifications = [];
  final List<ListingSubmission> _listings = [];
  int _seq = 0;
  bool _seeded = false;

  /// DEMO: the customer's e-Broker store. Its submissions appear in the moderation queue as
  /// e-Broker records, and decisions are written back to the same record the customer reads.
  DemoEBrokerRepository? ebroker;
  final Map<String, String> _ebLink = {}; // e-Broker id -> moderation id
  final Map<String, int> _ebRev = {};

  void _syncEBroker() {
    final eb = ebroker;
    if (eb == null) return;
    for (final (sub, rev) in eb.adminView()) {
      final linked = _ebLink[sub.id];
      final i = linked == null ? -1 : _listings.indexWhere((l) => l.id == linked);
      if (i >= 0 && _ebRev[sub.id] == rev) continue;
      final inp = sub.input;
      final old = i >= 0 ? _listings[i] : null;
      final next = ListingSubmission(
        id: old?.id ?? 'm${++_seq}',
        title: inp.title,
        description: inp.description,
        ownerName: 'Prototype owner (e-Broker)',
        location: '${inp.wilayat}, ${inp.governorate}',
        type: inp.type,
        source: ListingSource.eBroker,
        submittedAt: sub.submittedAt,
        status: ModerationStatus.pending,
        priceOmr: inp.priceOmr,
        sizeSqm: inp.sizeSqm,
        transaction: TransactionType.buy,
        photos: inp.photoNames,
        documents: [
          AdminDocument(id: 'd${++_seq}', label: tr('Owner photo ID'), fileName: inp.ownerIdName),
          AdminDocument(id: 'd${++_seq}', label: tr('Title deed'), fileName: inp.deedDocName),
        ],
        feeDisclosureAccepted: sub.feeAcceptedAt != null,
        history: old?.history ?? const [],
      );
      if (i >= 0) {
        _listings[i] = next;
      } else {
        _listings.add(next);
        _ebLink[sub.id] = next.id;
      }
      _ebRev[sub.id] = rev;
    }
  }

  String _reasonText(ReasonCode? r, String note) {
    final words = r == null
        ? ''
        : r.name.replaceAllMapped(RegExp('[A-Z]'), (m) => ' ${m[0]!.toLowerCase()}');
    final base = words.isEmpty ? '' : '${words[0].toUpperCase()}${words.substring(1)}.';
    return [base, note.trim()].where((x) => x.isNotEmpty).join(' ');
  }

  /// Test and QA hook: the next write fails with this error.
  Object? debugNextError;

  /// QA / tests: the next call finds the session expired.
  void debugExpireSession() => _expired = true;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  AdminSession _need() {
    final s = _session;
    if (s == null || _expired) throw const AdminSessionExpiredException();
    return s;
  }

  Future<AdminSession> _call({bool write = false}) async {
    await _lag();
    final s = _need();
    if (write) {
      if (qaCallsFail()) throw const ApiException(ApiErrorCode.network);
      final err = debugNextError;
      if (err != null) {
        debugNextError = null;
        throw err;
      }
    }
    return s;
  }

  // ---- auth
  @override
  Future<void> signIn(String email, String password) async {
    await _lag();
    final a = accounts[email.trim().toLowerCase()];
    // One generic failure: never say which of the two was wrong.
    if (a == null || password != demoPassword) throw const AdminAuthException();
    _pending = a;
    _session = null;
    _expired = false;
  }

  @override
  Future<AdminSession> verifyTotp(String code) async {
    await _lag();
    final p = _pending;
    if (p == null) throw const AdminSessionExpiredException();
    if (code != demoCode) throw const AdminTotpException();
    _session = p;
    _pending = null;
    return p;
  }

  @override
  Future<void> reauthenticate(String code) async {
    await _lag();
    _need();
    if (code != demoCode) throw const AdminTotpException();
  }

  @override
  Future<void> signOut() async {
    _session = null;
    _pending = null;
  }

  // ---- demo records (explicit, labelled, no real files)
  void seedDemoRecords() {
    if (_seeded || _verifications.isNotEmpty) return;
    _seeded = true;
    final now = _clock();
    AdminDocument doc(String label) => AdminDocument(
      id: 'd${++_seq}',
      label: label,
      fileName: 'demo-${label.toLowerCase().replaceAll(' ', '-')}.pdf',
    );
    VerificationItem v(
      ApplicantKind k,
      String name,
      int daysAgo, {
      bool resub = false,
      List<AdminDocument>? docs,
    }) => VerificationItem(
      id: 'v${++_seq}',
      applicantName: name,
      kind: k,
      submittedAt: now.subtract(Duration(days: daysAgo)),
      status: QueueStatus.pending,
      isResubmission: resub,
      details: {
        'Contact email': 'demo@example.test',
        'Phone': '9000 0000',
        'Governorate': 'Muscat',
      },
      documents:
          docs ?? [doc('Identity document'), doc('Registration certificate')],
    );
    _verifications
      ..add(v(ApplicantKind.agent, 'Demo applicant: real estate agent', 3))
      ..add(
        v(ApplicantKind.developer, 'Demo applicant: development company', 2),
      )
      ..add(
        v(
          ApplicantKind.construction,
          'Demo applicant: construction company',
          5,
          resub: true,
        ),
      )
      ..add(
        v(
          ApplicantKind.architecture,
          'Demo applicant: architecture studio',
          1,
          docs: [
            AdminDocument(
              id: 'd${++_seq}',
              label: tr('Registration certificate'),
              fileName: 'removed.pdf',
              available: false,
            ),
          ],
        ),
      )
      ..add(
        v(
          ApplicantKind.interiorExterior,
          'Demo applicant: interior and exterior design',
          4,
        ),
      );
    ListingSubmission l(
      String title,
      ListingSource src,
      PropertyType t,
      int daysAgo, {
      bool? fee,
      bool complete = true,
    }) => ListingSubmission(
      id: 'm${++_seq}',
      title: title,
      description: complete ? 'Demo description. No real property.' : '',
      ownerName: 'Demo owner',
      location: complete ? 'Bawshar, Muscat' : '',
      type: t,
      source: src,
      submittedAt: now.subtract(Duration(days: daysAgo)),
      priceOmr: complete ? 120000 : null,
      sizeSqm: complete ? 320 : null,
      photos: complete ? _demoPhotos(t) : const [],
      documents: complete ? [doc('Title deed')] : const [],
      feeDisclosureAccepted: fee,
    );
    _listings
      ..add(
        l('Demo listing: villa', ListingSource.agent, PropertyType.villa, 2),
      )
      ..add(
        l(
          'Demo listing: apartment (e-Broker)',
          ListingSource.eBroker,
          PropertyType.apartment,
          1,
          fee: true,
        ),
      )
      ..add(
        l(
          'Demo listing: incomplete submission',
          ListingSource.agent,
          PropertyType.shop,
          3,
          complete: false,
        ),
      );
  }

  bool get hasRecords => _seeded || _verifications.isNotEmpty || _listings.isNotEmpty;

  // ---- verification
  @override
  Future<List<VerificationItem>> list() async {
    await _call();
    final l = <VerificationItem>[..._verifications]..sort(compareQueue);
    return List.unmodifiable(l);
  }

  @override
  Future<VerificationItem?> get(String id) async {
    await _call();
    return _verifications.where((v) => v.id == id).firstOrNull;
  }

  @override
  Future<VerificationItem> claim(String id) async {
    final s = await _call(write: true);
    final i = _verifications.indexWhere((v) => v.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final v = _verifications[i];
    final now = _clock();
    if (v.claimedByOther(s.id, now)) {
      throw AdminLockedException(v.claimedByName ?? '');
    }
    if (!s.role.canDecide) return v; // read-only roles may look, not lock
    return _verifications[i] = v.copyWith(
      claimedById: s.id,
      claimedByName: s.name,
      claimExpiresAt: now.add(const Duration(minutes: 30)),
    );
  }

  @override
  Future<void> release(String id) async {
    final s = _session;
    final i = _verifications.indexWhere((v) => v.id == id);
    if (s != null && i >= 0 && _verifications[i].claimedById == s.id) {
      _verifications[i] = _verifications[i].copyWith(clearClaim: true);
    }
    final j = _listings.indexWhere((v) => v.id == id);
    if (s != null && j >= 0 && _listings[j].claimedById == s.id) {
      _listings[j] = _listings[j].copyWith(clearClaim: true);
    }
  }

  @override
  Future<VerificationItem> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  }) async {
    final s = await _call(write: true);
    if (!s.role.canDecide) throw const AdminForbiddenException();
    final i = _verifications.indexWhere((v) => v.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final v = _verifications[i];
    if (!v.open) throw const AdminConflictException();
    final now = _clock();
    if (v.claimedByOther(s.id, now)) {
      throw AdminLockedException(v.claimedByName ?? '');
    }
    if (decision != Decision.approve &&
        (reason == null ||
            (reason == ReasonCode.other && note.trim().isEmpty))) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    final rec = DecisionRecord(
      byId: s.id,
      byName: s.name,
      at: now,
      decision: decision,
      reason: reason,
      note: note.trim(),
    );
    QueueStatus next;
    String? firstApprover = v.firstApproverId;
    if (decision == Decision.approve) {
      if (v.isDeveloper) {
        if (v.status == QueueStatus.pending) {
          next = QueueStatus.awaitingSecondApproval;
          firstApprover = s.id;
        } else {
          if (!s.role.canSecondApprove) throw const AdminForbiddenException();
          if (v.firstApproverId == s.id) {
            throw const AdminSameApproverException();
          }
          next = QueueStatus.approved;
        }
      } else {
        next = QueueStatus.approved;
      }
    } else {
      next = decision == Decision.reject
          ? QueueStatus.rejected
          : QueueStatus.resubmissionRequired;
    }
    return _verifications[i] = v.copyWith(
      status: next,
      history: [...v.history, rec],
      clearClaim: true,
      firstApproverId: firstApprover,
    );
  }

  // ---- moderation (same lock and decision rules; a separate list)
  Future<List<ListingSubmission>> listListings() async {
    await _call();
    _syncEBroker();
    final l = <ListingSubmission>[..._listings]
      ..sort((a, b) => a.submittedAt.compareTo(b.submittedAt));
    return List.unmodifiable(l);
  }

  Future<ListingSubmission?> getListing(String id) async {
    await _call();
    _syncEBroker();
    return _listings.where((v) => v.id == id).firstOrNull;
  }

  Future<ListingSubmission> claimListing(String id) async {
    final s = await _call(write: true);
    _syncEBroker();
    final i = _listings.indexWhere((v) => v.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final v = _listings[i];
    final now = _clock();
    if (v.claimedByOther(s.id, now)) {
      throw AdminLockedException(v.claimedByName ?? '');
    }
    if (!s.role.canDecide) return v;
    return _listings[i] = v.copyWith(
      claimedById: s.id,
      claimedByName: s.name,
      claimExpiresAt: now.add(const Duration(minutes: 30)),
    );
  }

  Future<ListingSubmission> decideListing(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  }) async {
    final s = await _call(write: true);
    if (!s.role.canDecide) throw const AdminForbiddenException();
    _syncEBroker();
    final i = _listings.indexWhere((v) => v.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final v = _listings[i];
    if (!v.open) throw const AdminConflictException();
    final now = _clock();
    if (v.claimedByOther(s.id, now)) {
      throw AdminLockedException(v.claimedByName ?? '');
    }
    if (decision == Decision.approve && v.missing.isNotEmpty) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    if (decision != Decision.approve &&
        (reason == null ||
            (reason == ReasonCode.other && note.trim().isEmpty))) {
      throw const ApiException(ApiErrorCode.validationFailed);
    }
    final rec = DecisionRecord(
      byId: s.id,
      byName: s.name,
      at: now,
      decision: decision,
      reason: reason,
      note: note.trim(),
    );
    final next = switch (decision) {
      Decision.approve => ModerationStatus.approved,
      Decision.requestResubmission => ModerationStatus.resubmissionRequired,
      Decision.reject => ModerationStatus.rejected,
    };
    final decided = _listings[i] = v.copyWith(
      status: next,
      history: [...v.history, rec],
      clearClaim: true,
    );
    // An e-Broker record: the customer sees the same outcome in Activity.
    final ebId = _ebLink.entries.where((e) => e.value == id).firstOrNull?.key;
    if (ebId != null) {
      ebroker?.applyAdminDecision(
        ebId,
        switch (decision) {
          Decision.approve => EBrokerStatus.approved,
          Decision.requestResubmission => EBrokerStatus.resubmissionRequired,
          Decision.reject => EBrokerStatus.rejected,
        },
        feedback: _reasonText(reason, note),
      );
    }
    return decided;
  }

  /// QA / tests: add a record directly.
  VerificationItem debugAddVerification(
    VerificationItem Function(String id) build,
  ) {
    final v = build('v${++_seq}');
    _verifications.add(v);
    return v;
  }

  ListingSubmission debugAddListing(
    ListingSubmission Function(String id) build,
  ) {
    final v = build('m${++_seq}');
    _listings.add(v);
    return v;
  }

  AdminSession? get session => _session;
}

/// Verification and moderation share one store, so each contract gets a thin adapter.
class _ModerationAdapter implements ModerationRepository {
  final DemoAdminStore s;
  _ModerationAdapter(this.s);
  @override
  Future<List<ListingSubmission>> list() => s.listListings();
  @override
  Future<ListingSubmission?> get(String id) => s.getListing(id);
  @override
  Future<ListingSubmission> claim(String id) => s.claimListing(id);
  @override
  Future<void> release(String id) => s.release(id);
  @override
  Future<ListingSubmission> decide(
    String id,
    Decision decision, {
    ReasonCode? reason,
    String note = '',
  }) => s.decideListing(id, decision, reason: reason, note: note);
}

/// Applies the console's role rules to ad management before delegating to the demo store.
class _AdAdminAdapter implements AdAdminRepository {
  final DemoAdminStore s;
  _AdAdminAdapter(this.s);
  AdminSession _who() {
    final x = s.session;
    if (x == null) throw const AdminSessionExpiredException();
    return x;
  }

  void _manage() {
    if (!_who().role.canManageAds) throw const AdminForbiddenException();
  }

  @override
  Future<List<SponsoredAd>> list() async {
    _who();
    return s.ads.list();
  }

  @override
  Future<SponsoredAd?> get(String id) async {
    _who();
    return s.ads.get(id);
  }

  @override
  Future<SponsoredAd> create(AdDraft d) async {
    _manage();
    return s.ads.create(d);
  }

  @override
  Future<SponsoredAd> update(String id, AdDraft d) async {
    _manage();
    return s.ads.update(id, d);
  }

  @override
  Future<SponsoredAd> submitForReview(String id) async {
    _manage();
    return s.ads.submitForReview(id);
  }

  @override
  Future<SponsoredAd> pause(String id) async {
    _manage();
    return s.ads.pause(id);
  }

  @override
  Future<SponsoredAd> resume(String id) async {
    _manage();
    return s.ads.resume(id);
  }

  @override
  Future<List<SponsoredAd>> reorder(List<String> ids) async {
    _manage();
    return s.ads.reorder(ids);
  }

  @override
  Future<SponsoredAd> decide(
    String id, {
    required AdStatus outcome,
    String? reasonCode,
    String note = '',
  }) async {
    if (!_who().role.canReviewAds) throw const AdminForbiddenException();
    return s.ads.decide(
      id,
      outcome: outcome,
      reasonCode: reasonCode,
      note: note,
    );
  }
}

// ------------------------------------------------------------------ providers

/// In the demo the console shares the customer app's campaign store, so a banner changed here is
/// the banner the Homes serve.
final adminStoreProvider = Provider<DemoAdminStore?>((ref) {
  if (!kUseDemoBackend) return null;
  final ads = ref.watch(adRepositoryProvider);
  final store = DemoAdminStore(ads: ads is DemoAdRepository ? ads : null);
  final eb = ref.watch(eBrokerRepositoryProvider);
  if (eb is DemoEBrokerRepository) store.ebroker = eb;
  return store;
});
final adminAuthRepositoryProvider = Provider<AdminAuthRepository>(
  (ref) =>
      ref.watch(adminStoreProvider) ?? const UnavailableAdminAuthRepository(),
);
final verificationRepositoryProvider = Provider<VerificationRepository>(
  (ref) =>
      ref.watch(adminStoreProvider) ??
      const UnavailableVerificationRepository(),
);
final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  final s = ref.watch(adminStoreProvider);
  return s == null
      ? const UnavailableModerationRepository()
      : _ModerationAdapter(s);
});
final adAdminRepositoryProvider = Provider<AdAdminRepository>((ref) {
  final s = ref.watch(adminStoreProvider);
  return s == null ? const UnavailableAdAdminRepository() : _AdAdminAdapter(s);
});

final verificationListProvider =
    FutureProvider.autoDispose<List<VerificationItem>>(
      (ref) => ref.watch(verificationRepositoryProvider).list(),
    );
final verificationItemProvider = FutureProvider.autoDispose
    .family<VerificationItem?, String>(
      (ref, id) => ref.watch(verificationRepositoryProvider).get(id),
    );
final moderationListProvider =
    FutureProvider.autoDispose<List<ListingSubmission>>(
      (ref) => ref.watch(moderationRepositoryProvider).list(),
    );
final moderationItemProvider = FutureProvider.autoDispose
    .family<ListingSubmission?, String>(
      (ref, id) => ref.watch(moderationRepositoryProvider).get(id),
    );
final adminAdsProvider = FutureProvider.autoDispose<List<SponsoredAd>>(
  (ref) => ref.watch(adAdminRepositoryProvider).list(),
);
final adminAdProvider = FutureProvider.autoDispose.family<SponsoredAd?, String>(
  (ref, id) => ref.watch(adAdminRepositoryProvider).get(id),
);

/// The properties of a demo listing's type, used only to label things.
String adminTypeKey(PropertyType t) => 'ptype.${t.name}';

/// Photographs the demo submissions carry, picked by the kind of property. Real submissions carry
/// the file names the agent chose; the moderation screens show a picture for the bundled ones.
List<String> _demoPhotos(PropertyType t) => switch (t) {
  PropertyType.apartment || PropertyType.penthouse => const [
    'assets/properties/p2/06_Seaview_balcony_overlooking_coa.jpg',
    'assets/properties/p2/08_Open_living_and_dining_apartment.jpg',
  ],
  PropertyType.shop || PropertyType.office || PropertyType.warehouse || PropertyType.building => const [
    'assets/properties/p6/02_Empty_contemporary_commercial_sh.jpg',
    'assets/properties/p6/04_Modern_commercial_building_exterior.jpg',
  ],
  _ => const [
    'assets/properties/p1/08_Contemporary_villa_front_facade_.jpg',
    'assets/properties/p1/17_Contemporary_living_room_interio.jpg',
  ],
};
