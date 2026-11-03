import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/backend_mode.dart';
import '../../core/config/qa_faults.dart';
import '../../data/api/account_api.dart' show ApiErrorCode, ApiException;

/// AqaratiBroker is AQARATI's own programme of verified, badged brokers (a `seller` grant with the
/// `aqarati_broker` sub-type, created by a Super Admin). It is NOT Aqary e-Broker, the owner selling
/// flow. A badge is shown only for a broker the service says is approved; the app never decides it.
class AqaratiBroker {
  final String id;
  final String name;
  final String area;
  final String about;

  /// Shown only when the service gives it; no number means no Call button, with a reason.
  final String? phone;

  /// Ids of this broker's approved listings.
  final List<String> propertyIds;
  const AqaratiBroker({
    required this.id,
    required this.name,
    this.area = '',
    this.about = '',
    this.phone,
    this.propertyIds = const [],
  });
}

abstract class BrokerRepository {
  /// Approved Aqarati Brokers only.
  Future<List<AqaratiBroker>> brokers();
  Future<AqaratiBroker?> broker(String id);
}

class UnavailableBrokerRepository implements BrokerRepository {
  const UnavailableBrokerRepository();
  Never _no() => throw const ApiException(ApiErrorCode.network);
  @override
  Future<List<AqaratiBroker>> brokers() async => _no();
  @override
  Future<AqaratiBroker?> broker(String id) async => _no();
}

/// DEMO ONLY. The public demo has no brokers (none are invented). QA builds (`REVIEW_TOOLS`) add
/// two clearly named sample brokers so the profile can be looked at.
class DemoBrokerRepository implements BrokerRepository {
  DemoBrokerRepository({
    List<AqaratiBroker> seed = const [],
    this.latency = const Duration(milliseconds: 250),
  }) : _items = List.of(seed);
  final List<AqaratiBroker> _items;
  final Duration latency;

  Future<void> _lag() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (qaCallsFail()) throw const ApiException(ApiErrorCode.network);
  }

  @override
  Future<List<AqaratiBroker>> brokers() async {
    await _lag();
    return List.unmodifiable(_items);
  }

  @override
  Future<AqaratiBroker?> broker(String id) async {
    await _lag();
    return _items.where((b) => b.id == id).firstOrNull;
  }
}

const kQaSampleBrokers = [
  AqaratiBroker(
    id: 'qa-broker-1',
    name: 'Al Noor Realty (sample)',
    area: 'Muscat',
    about: 'A fictional sample profile for this preview. Not a real broker.',
    phone: '+968 9000 0101',
    propertyIds: ['p1', 'p2'],
  ),
  AqaratiBroker(
    id: 'qa-broker-2',
    name: 'Salalah Coast Realty (sample)',
    area: 'Salalah',
    about: 'A fictional sample profile with no phone number and no listings.',
  ),
];

final brokerRepositoryProvider = Provider<BrokerRepository>(
  (ref) => kUseDemoBackend
      ? DemoBrokerRepository(
          seed: kShowReviewTools ? kQaSampleBrokers : const [],
        )
      : const UnavailableBrokerRepository(),
);
final brokersProvider = FutureProvider.autoDispose<List<AqaratiBroker>>(
  (ref) => ref.watch(brokerRepositoryProvider).brokers(),
);
final brokerProvider = FutureProvider.autoDispose
    .family<AqaratiBroker?, String>(
      (ref, id) => ref.watch(brokerRepositoryProvider).broker(id),
    );
