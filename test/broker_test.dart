import 'package:aqarati_app/features/broker/broker_repository.dart';
import 'package:aqarati_app/features/broker/broker_screens.dart';
import 'package:aqarati_app/features/leads/lead_repository.dart'
    show PhoneLauncher;
import 'package:aqarati_app/features/leads/phone_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _Launcher implements PhoneLauncher {
  final bool ok;
  final List<String> dialled = [];
  _Launcher({this.ok = true});
  @override
  Future<bool> dial(String number) async {
    dialled.add(number);
    return ok;
  }
}

Widget app(
  BrokerRepository repo, {
  String start = '/broker',
  PhoneLauncher? launcher,
}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/app/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/sell',
        builder: (_, _) => const Scaffold(body: Text('SELL')),
      ),
      GoRoute(
        path: '/property/:id/viewing',
        builder: (_, s) =>
            Scaffold(body: Text('VIEWING ${s.pathParameters['id']}')),
      ),
      GoRoute(path: '/broker', builder: (_, _) => const BrokerIntroScreen()),
      GoRoute(
        path: '/broker/list',
        builder: (_, _) => const BrokerListScreen(),
      ),
      GoRoute(
        path: '/broker/:id',
        builder: (_, s) => BrokerProfileScreen(id: s.pathParameters['id']!),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      brokerRepositoryProvider.overrideWithValue(repo),
      if (launcher != null) phoneLauncherProvider.overrideWithValue(launcher),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    ),
  );
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void big(WidgetTester t) {
  t.view.physicalSize = const Size(393, 1800);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

DemoBrokerRepository demo({List<AqaratiBroker> seed = kQaSampleBrokers}) =>
    DemoBrokerRepository(seed: seed, latency: Duration.zero);

void main() {
  testWidgets('the introduction explains the badge and separates e-Broker', (
    t,
  ) async {
    big(t);
    await t.pumpWidget(app(demo()));
    await settle(t);
    expect(find.text('What the badge means'), findsOneWidget);
    expect(find.text('Not the same as Aqary e-Broker'), findsOneWidget);
    expect(find.text('Find a broker'), findsOneWidget);
    await t.tap(find.text('Sell with Aqary e-Broker'));
    await settle(t);
    expect(find.text('SELL'), findsOneWidget);
  });

  testWidgets('no brokers: an honest empty state, no invented broker', (
    t,
  ) async {
    big(t);
    await t.pumpWidget(app(demo(seed: const []), start: '/broker/list'));
    await settle(t);
    expect(find.text('No brokers are listed yet'), findsOneWidget);
    expect(find.byType(AqaratiBrokerBadge), findsNothing);
  });

  testWidgets('service unreachable: error with Try again', (t) async {
    big(t);
    await t.pumpWidget(
      app(const UnavailableBrokerRepository(), start: '/broker/list'),
    );
    await settle(t);
    expect(find.text('Try again'), findsWidgets);
    expect(find.byType(AqaratiBrokerBadge), findsNothing);
  });

  testWidgets('the directory shows a badge only for returned brokers', (
    t,
  ) async {
    big(t);
    await t.pumpWidget(app(demo(), start: '/broker/list'));
    await settle(t);
    expect(find.byType(AqaratiBrokerBadge), findsNWidgets(2));
    await t.tap(find.textContaining('Al Noor Realty'));
    await settle(t);
    expect(find.text('Call'), findsOneWidget);
  });

  testWidgets('Call opens the dialler and claims nothing more', (t) async {
    big(t);
    final l = _Launcher();
    await t.pumpWidget(app(demo(), start: '/broker/qa-broker-1', launcher: l));
    await settle(t);
    await t.tap(find.text('Call'));
    await settle(t);
    expect(l.dialled, ['+968 9000 0101']);
    expect(
      find.textContaining('does not know whether the call connects'),
      findsOneWidget,
    );
    expect(find.textContaining('call connected'), findsNothing);
  });

  testWidgets('a dialler that cannot open says so', (t) async {
    big(t);
    await t.pumpWidget(
      app(demo(), start: '/broker/qa-broker-1', launcher: _Launcher(ok: false)),
    );
    await settle(t);
    await t.tap(find.text('Call'));
    await settle(t);
    expect(
      find.text('We could not open the dialler on this device.'),
      findsOneWidget,
    );
  });

  testWidgets('no phone number: no Call button, with the reason', (t) async {
    big(t);
    await t.pumpWidget(app(demo(), start: '/broker/qa-broker-2'));
    await settle(t);
    expect(find.text('Call'), findsNothing);
    expect(
      find.text('This broker has not shared a phone number.'),
      findsOneWidget,
    );
    expect(
      find.text('This broker has no approved listings right now.'),
      findsOneWidget,
    );
  });

  testWidgets('a listing links to the existing viewing request', (t) async {
    big(t);
    await t.pumpWidget(app(demo(), start: '/broker/qa-broker-1'));
    await settle(t);
    expect(find.text('Request a viewing'), findsWidgets);
    await t.tap(find.text('Request a viewing').first);
    await settle(t);
    expect(find.textContaining('VIEWING'), findsOneWidget);
  });

  testWidgets('an unknown broker shows not found, not a blank page', (t) async {
    big(t);
    await t.pumpWidget(app(demo(), start: '/broker/nope'));
    await settle(t);
    expect(find.text('We could not find this broker.'), findsOneWidget);
  });
}
