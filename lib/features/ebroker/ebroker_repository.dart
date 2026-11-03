import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../core/config/qa_faults.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import '../devbuild/db_models.dart' show PermissionDeniedException;
import '../../data/models/enums.dart' show PropertyType;
import 'ebroker_models.dart';

/// Customer side of Aqary e-Broker (`POST /properties` for a buyer who is selling). The service owns
/// review, duplicate detection and the fee; the app only reflects what it answers.
abstract class EBrokerRepository {
  Future<List<EBrokerSubmission>> mine();

  /// Null when it does not exist; throws [PermissionDeniedException] for someone else's.
  Future<EBrokerSubmission?> get(String id);
  Future<EBrokerSubmission> submit(EBrokerInput input);
  Future<EBrokerSubmission> resubmit(String id, EBrokerInput input);
}

class UnavailableEBrokerRepository implements EBrokerRepository {
  const UnavailableEBrokerRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<EBrokerSubmission>> mine() async => _no();
  @override
  Future<EBrokerSubmission?> get(String id) async => _no();
  @override
  Future<EBrokerSubmission> submit(EBrokerInput input) async => _no();
  @override
  Future<EBrokerSubmission> resubmit(String id, EBrokerInput input) async =>
      _no();
}

/// DEMO ONLY: in memory. A reviewer's decision is simulated through [debugSet] (QA tools only); new
/// submissions always start in review and nothing here approves anything by itself.
class DemoEBrokerRepository implements EBrokerRepository {
  DemoEBrokerRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration latency;
  final DateTime Function() _clock;
  final List<EBrokerSubmission> _items = [];
  final Set<String> _foreign = {};
  int _seq = 0;

  /// Bumped on every submit or resubmit, so the admin console can tell a changed record.
  final Map<String, int> _rev = {};

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

  bool _dup(String deed, {String? except}) => _items.any(
    (s) =>
        s.id != except &&
        normaliseEBrokerDeed(s.input.titleDeed) == normaliseEBrokerDeed(deed) &&
        s.status != EBrokerStatus.rejected,
  );

  @override
  Future<List<EBrokerSubmission>> mine() async {
    await _lag();
    return List.unmodifiable(_items.reversed);
  }

  @override
  Future<EBrokerSubmission?> get(String id) async {
    await _lag();
    if (_foreign.contains(id)) throw const PermissionDeniedException();
    return _items.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<EBrokerSubmission> submit(EBrokerInput input) async {
    await _lag();
    if (!input.feeAccepted)
      throw const ApiException(ApiErrorCode.validationFailed);
    if (_dup(input.titleDeed)) throw const EBrokerDuplicateException();
    final s = EBrokerSubmission(
      id: 'eb${++_seq}',
      input: input,
      status: EBrokerStatus.pendingVerification,
      submittedAt: _clock(),
      feeAcceptedAt: _clock(),
    );
    _items.add(s);
    _rev[s.id] = 1;
    return s;
  }

  @override
  Future<EBrokerSubmission> resubmit(String id, EBrokerInput input) async {
    await _lag();
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    if (!_items[i].canResubmit) throw const ApiException(ApiErrorCode.conflict);
    if (_dup(input.titleDeed, except: id))
      throw const EBrokerDuplicateException();
    _rev[id] = (_rev[id] ?? 1) + 1;
    return _items[i] = _items[i].copyWith(
      input: input,
      status: EBrokerStatus.pendingVerification,
      feeAcceptedAt: _clock(),
    );
  }

  /// DEMO: what the admin console sees, with a revision per record. Same objects the customer
  /// reads, so the two screens cannot disagree.
  List<(EBrokerSubmission, int)> adminView() => [
    for (final s in _items) (s, _rev[s.id] ?? 1),
  ];

  /// DEMO: the console's decision, applied to the same record the customer reads.
  void applyAdminDecision(
    String id,
    EBrokerStatus status, {
    String? feedback,
  }) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _items[i] = EBrokerSubmission(
      id: _items[i].id,
      input: _items[i].input,
      status: status,
      feedback: status == EBrokerStatus.approved ? null : feedback,
      submittedAt: _items[i].submittedAt,
      feeAcceptedAt: _items[i].feeAcceptedAt,
    );
  }

  /// REVIEW TOOLS ONLY: fictional submissions in several states (see [seedActivityDemo]).
  void seedDemo(List<EBrokerSubmission> items) => _items.addAll(items);

  /// QA only: a reviewer's decision.
  void debugSet(String id, EBrokerStatus status, {String? feedback}) {
    final i = _items.indexWhere((s) => s.id == id);
    if (i >= 0) {
      _items[i] = EBrokerSubmission(
        id: _items[i].id,
        input: _items[i].input,
        status: status,
        feedback: feedback,
        submittedAt: _items[i].submittedAt,
        feeAcceptedAt: _items[i].feeAcceptedAt,
      );
    }
  }

  /// QA only: a submission that belongs to someone else.
  String debugForeignId() {
    final id = 'eb-foreign${++_seq}';
    _foreign.add(id);
    return id;
  }
}

/// REVIEW TOOLS ONLY, and only for `?session=activity`: four clearly fictional submissions, one in
/// each state, so every status of the Selling tab can be reviewed. Never runs in a normal build, and
/// never touches the sessions the tests use.
void seedActivityDemo(DemoEBrokerRepository repo) {
  if (!kShowReviewTools || !kIsWeb) return;
  if ((Uri.base.queryParameters['session'] ?? '') != 'activity') return;
  EBrokerInput mk(String title, String deed, PropertyType t) => EBrokerInput(
    title: title,
    description: 'Fictional demo submission.',
    type: t,
    governorate: 'Muscat',
    wilayat: 'Bawshar',
    sizeSqm: 420,
    priceOmr: 120000,
    titleDeed: deed,
    ownerIdName: 'owner-id.jpg',
    deedDocName: 'title-deed.pdf',
    photoNames: const ['photo-1.jpg'],
    feeAccepted: true,
  );
  final now = DateTime.now();
  EBrokerSubmission sub(String id, String title, String deed, PropertyType t, EBrokerStatus st, int daysAgo, {String? feedback}) =>
      EBrokerSubmission(id: id, input: mk(title, deed, t), status: st, feedback: feedback, submittedAt: now.subtract(Duration(days: daysAgo)), feeAcceptedAt: now.subtract(Duration(days: daysAgo)));
  repo.seedDemo([
    sub('eb-demo1', 'Demo villa, in review (fictional)', 'DEMO-1001', PropertyType.villa, EBrokerStatus.pendingVerification, 1),
    sub('eb-demo2', 'Demo apartment, approved (fictional)', 'DEMO-1002', PropertyType.apartment, EBrokerStatus.approved, 6),
    sub('eb-demo3', 'Demo plot, rejected (fictional)', 'DEMO-1003', PropertyType.residentialLand, EBrokerStatus.rejected, 9, feedback: 'The title deed does not match the owner (fictional reason).'),
    sub('eb-demo4', 'Demo shop, changes requested (fictional)', 'DEMO-1004', PropertyType.shop, EBrokerStatus.resubmissionRequired, 3, feedback: 'Add a clearer photo of the deed (fictional reason).'),
  ]);
}

final eBrokerRepositoryProvider = Provider<EBrokerRepository>((ref) {
  if (!kUseDemoBackend) return const UnavailableEBrokerRepository();
  final repo = DemoEBrokerRepository();
  seedActivityDemo(repo);
  return repo;
});
final myEBrokerProvider = FutureProvider.autoDispose<List<EBrokerSubmission>>(
  (ref) => ref.watch(eBrokerRepositoryProvider).mine(),
);
final eBrokerProvider = FutureProvider.autoDispose
    .family<EBrokerSubmission?, String>(
      (ref, id) => ref.watch(eBrokerRepositoryProvider).get(id),
    );
