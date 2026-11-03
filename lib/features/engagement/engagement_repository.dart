import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/qa_faults.dart';

import '../../core/config/backend_mode.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;
import 'engagement_models.dart';

/// Frontend contract for professional engagements. The real API is not confirmed; screens depend
/// only on this. A request is only ever "waiting" until the professional confirms: the app never
/// presents it as confirmed on its own.
abstract class EngagementRepository {
  Future<ClientEngagement> request({
    required String professionalId,
    required String professionalName,
    required String professionalType,
  });
  Future<ClientEngagement> confirm(String id);
  Future<ClientEngagement> cancel(String id);
  Future<List<ClientEngagement>> list();
  Future<ClientEngagement?> get(String id);
}

/// Used when no real service is wired: every call fails like an offline request.
class UnavailableEngagementRepository implements EngagementRepository {
  const UnavailableEngagementRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<ClientEngagement> request({
    required String professionalId,
    required String professionalName,
    required String professionalType,
  }) async => _no();
  @override
  Future<ClientEngagement> confirm(String id) async => _no();
  @override
  Future<ClientEngagement> cancel(String id) async => _no();
  @override
  Future<List<ClientEngagement>> list() async => _no();
  @override
  Future<ClientEngagement?> get(String id) async => _no();
}

/// DEMO ONLY: in memory. The professional's answer is simulated through [debugSet] (QA tools only).
class DemoEngagementRepository implements EngagementRepository {
  DemoEngagementRepository({
    this.latency = const Duration(milliseconds: 350),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;
  final Duration latency;
  final DateTime Function() _clock;
  final List<ClientEngagement> _items = [];
  int _seq = 0;

  /// Test and QA hook: the next [request] fails with this error.
  Object? debugNextError;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (qaCallsFail()) throw const ApiException(ApiErrorCode.network);
  }

  @override
  Future<ClientEngagement> request({
    required String professionalId,
    required String professionalName,
    required String professionalType,
  }) async {
    await _lag();
    final err = debugNextError;
    if (err != null) {
      debugNextError = null;
      throw err;
    }
    final open = _items
        .where(
          (e) =>
              e.professionalId == professionalId &&
              e.phaseAt(_clock()) != EngagementPhase.expired &&
              (e.isWaiting || e.phase == EngagementPhase.confirmed),
        )
        .firstOrNull;
    if (open != null) throw DuplicateEngagementException(open.id);
    final e = ClientEngagement(
      id: 'e${++_seq}',
      professionalId: professionalId,
      professionalName: professionalName,
      professionalType: professionalType,
      phase: EngagementPhase.awaitingProfessional,
      requestedAt: _clock(),
    );
    _items.add(e);
    return e;
  }

  @override
  Future<ClientEngagement> confirm(String id) async {
    await _lag();
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    final e = _items[i];
    if (e.phase != EngagementPhase.awaitingMe ||
        e.phaseAt(_clock()) == EngagementPhase.expired) {
      throw const ApiException(ApiErrorCode.conflict);
    }
    return _items[i] = e.copyWith(
      phase: EngagementPhase.confirmed,
      confirmedAt: _clock(),
    );
  }

  @override
  Future<ClientEngagement> cancel(String id) async {
    await _lag();
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) throw const ApiException(ApiErrorCode.server);
    if (!_items[i].isWaiting) throw const ApiException(ApiErrorCode.conflict);
    return _items[i] = _items[i].copyWith(phase: EngagementPhase.cancelled);
  }

  @override
  Future<List<ClientEngagement>> list() async {
    await _lag();
    return List.unmodifiable(_items.reversed);
  }

  @override
  Future<ClientEngagement?> get(String id) async {
    await _lag();
    return _items.where((e) => e.id == id).firstOrNull;
  }

  /// REVIEW TOOLS ONLY: fictional engagements in several phases (see [seedActivityDemo]).
  void seedDemo(List<ClientEngagement> items) => _items.addAll(items);

  /// QA only: simulates the professional's answer (or, with [awaitingMe], the professional asking first).
  void debugSet(
    String id,
    EngagementPhase phase, {
    DateTime? requestedAt,
    DateTime? confirmedAt,
  }) {
    final i = _items.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final e = _items[i];
    _items[i] = ClientEngagement(
      id: e.id,
      professionalId: e.professionalId,
      professionalName: e.professionalName,
      professionalType: e.professionalType,
      phase: phase,
      requestedAt: requestedAt ?? e.requestedAt,
      confirmedAt: phase == EngagementPhase.confirmed
          ? (confirmedAt ?? _clock())
          : e.confirmedAt,
    );
  }
}

/// REVIEW TOOLS ONLY, and only for `?session=activity`: fictional professional engagements in
/// several phases for visual review. Never runs in a normal build.
void seedActivityDemo(DemoEngagementRepository repo) {
  if (!kShowReviewTools || !kIsWeb) return;
  if ((Uri.base.queryParameters['session'] ?? '') != 'activity') return;
  final now = DateTime.now();
  ClientEngagement eng(String id, String pid, String name, String type, EngagementPhase ph, int daysAgo) =>
      ClientEngagement(id: id, professionalId: pid, professionalName: name, professionalType: type, phase: ph, requestedAt: now.subtract(Duration(days: daysAgo)), confirmedAt: ph == EngagementPhase.confirmed ? now.subtract(Duration(days: daysAgo - 1)) : null);
  repo.seedDemo([
    eng('en-demo1', 'demo-a1', 'Wadi Architecture', 'architecture', EngagementPhase.awaitingMe, 2),
    eng('en-demo2', 'demo-c1', 'Sahari Contracting', 'construction', EngagementPhase.confirmed, 8),
    eng('en-demo3', 'demo-i1', 'Dar Nuqta Interiors', 'interiorExterior', EngagementPhase.declined, 5),
    eng('en-demo4', 'demo-d1', 'Zahra Developments', 'developer', EngagementPhase.cancelled, 4),
  ]);
}

final engagementRepositoryProvider = Provider<EngagementRepository>(
  (ref) {
    if (!kUseDemoBackend) return const UnavailableEngagementRepository();
    final repo = DemoEngagementRepository();
    seedActivityDemo(repo);
    return repo;
  },
);
final engagementsProvider = FutureProvider.autoDispose<List<ClientEngagement>>(
  (ref) => ref.watch(engagementRepositoryProvider).list(),
);
final engagementProvider = FutureProvider.autoDispose
    .family<ClientEngagement?, String>(
      (ref, id) => ref.watch(engagementRepositoryProvider).get(id),
    );
