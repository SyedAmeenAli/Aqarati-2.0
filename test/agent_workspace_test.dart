import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/features/agent/agent_crm.dart';
import 'package:aqarati_app/features/agent/agent_routes.dart';
import 'package:aqarati_app/features/agent/agent_screens.dart';
import 'package:aqarati_app/features/agent/agent_shell.dart';
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/search/aq_filter_sheet.dart' show AQChoicePill;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _agent = MeSession(
  account: AccountState.active,
  purpose: SignupPurpose.realEstateAgent,
  grant: GrantState.approved,
);
const _buyer = MeSession(
  account: AccountState.active,
  purpose: SignupPurpose.userToShop,
);

late ProviderContainer box;

Widget app({
  String start = '/agent',
  MeSession me = _agent,
  bool dark = false,
  bool rtl = false,
  double scale = 1,
}) => ProviderScope(
  overrides: [meProvider.overrideWith((ref) async => me)],
  child: Consumer(
    builder: (context, ref, _) {
      box = ProviderScope.containerOf(context);
      return MaterialApp.router(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        locale: Locale(rtl ? 'ar' : 'en'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        routerConfig: GoRouter(
          initialLocation: start,
          routes: [
            ShellRoute(
              builder: (c, s, child) => AgentShell(child: child),
              routes: [
                ...agentShellRoutes(),
                for (final p in ['/agent/listings', '/agent/leads'])
                  GoRoute(path: p, builder: (_, s) => Text('STUB ${s.uri}')),
              ],
            ),
            GoRoute(path: '/app/home', builder: (_, _) => const Text('CUSTOMER HOME')),
            GoRoute(path: '/:p(.*)', builder: (_, s) => Text('AT ${s.uri}')),
          ],
        ),
      );
    },
  ),
);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void phone(WidgetTester t, {double w = 393, double h = 1800}) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('CRM rules (pure)', () {
    final now = DateTime(2026, 10, 29, 12);
    test('the seed is deterministic, fictional and varied', () {
      final s = seedAgentCrm(now);
      expect(s.contacts.length, 8);
      expect(s.contacts.every((c) => c.email.endsWith('@example.test')), isTrue);
      expect(s.contacts.map((c) => c.status).toSet().length, LeadStatus.values.length);
      expect(seedAgentCrm(now).contacts.map((c) => c.id), s.contacts.map((c) => c.id));
    });

    test('search matches name, place and interest; status narrows; sort orders', () {
      final all = seedAgentCrm(now).contacts;
      expect(filterContacts(all, query: 'layla').map((c) => c.id), ['C1']);
      expect(filterContacts(all, query: 'nizwa').map((c) => c.id), ['C5']);
      expect(filterContacts(all, query: 'shop').map((c) => c.id), ['C4']);
      expect(filterContacts(all, status: LeadStatus.fresh).length, 2);
      expect(filterContacts(all, query: 'zzz'), isEmpty);
      final byName = filterContacts(all, sort: ContactSort.name).map((c) => c.name).toList();
      expect(byName, [...byName]..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())));
      final byFollow = filterContacts(all, sort: ContactSort.follow);
      expect(byFollow.last.nextFollowUp, isNull, reason: 'no follow-up sorts last');
      final dated = byFollow.where((c) => c.nextFollowUp != null).toList();
      for (var i = 1; i < dated.length; i++) {
        expect(dated[i].nextFollowUp!.isBefore(dated[i - 1].nextFollowUp!), isFalse);
      }
    });

    test('add, edit, note, status and follow-up change the local records', () {
      final crm = AgentCrm(now);
      final id = crm.addContact(name: 'Test Person', phone: '90000000', interests: ['Villa']);
      expect(crm.contact(id)!.status, LeadStatus.fresh);
      expect(crm.state.contacts.first.id, id);
      crm.addNote(id, '  Called back  ');
      expect(crm.contact(id)!.notes.first.text, 'Called back');
      crm.addNote(id, '   ');
      expect(crm.contact(id)!.notes.length, 2, reason: 'a blank note is not saved');
      crm.setStatus(id, LeadStatus.viewing);
      expect(crm.contact(id)!.status, LeadStatus.viewing);
      expect(crm.contact(id)!.notes.first.kind, NoteKind.status);
      final before = crm.state.appointments.length;
      final at = DateTime(2026, 11, 2, 10);
      crm.scheduleFollowUp(id, at);
      expect(crm.contact(id)!.nextFollowUp, at);
      expect(crm.state.appointments.length, before + 1);
      crm.scheduleFollowUp(id, DateTime(2026, 11, 5, 10));
      expect(crm.state.appointments.length, before + 1, reason: 'one open follow-up per contact');
      crm.setStatus(id, LeadStatus.won);
      expect(crm.contact(id)!.nextFollowUp, isNull, reason: 'a closed lead has no follow-up');
      crm.edit(id, (c) => c.copyWith(name: 'Renamed'));
      expect(crm.contact(id)!.name, 'Renamed');
    });

    test('appointments reschedule, finish and cancel', () {
      final crm = AgentCrm(now);
      crm.reschedule('A1', DateTime(2026, 12, 1, 9));
      expect(crm.state.appointments.firstWhere((a) => a.id == 'A1').at, DateTime(2026, 12, 1, 9));
      crm.setAppointmentStatus('A2', AppointmentStatus.done);
      crm.setAppointmentStatus('A3', AppointmentStatus.cancelled);
      expect(crm.state.appointments.firstWhere((a) => a.id == 'A2').status, AppointmentStatus.done);
      expect(crm.state.appointments.firstWhere((a) => a.id == 'A3').status, AppointmentStatus.cancelled);
    });
  });

  group('agent workspace', () {
    testWidgets('on a phone has Dashboard, Listings, Contacts, Calendar and More (Analytics is under More) and none of the customer tabs', (t) async {
      phone(t);
      await t.pumpWidget(app());
      await settle(t);
      for (final s in ['Dashboard', 'Listings', 'Contacts', 'Calendar', 'More']) {
        expect(find.text(s), findsWidgets, reason: s);
      }
      for (final s in ['Explore', 'Activity', 'Account']) {
        expect(find.text(s), findsNothing, reason: 'customer tab $s');
      }
      expect(find.text('Buy a property'), findsNothing);
    });

    testWidgets('each destination shows different content', (t) async {
      phone(t);
      final seen = <String>{};
      for (final (path, marker) in [
        ('/agent', 'Your workspace'),
        ('/agent/contacts', 'Search name, place or interest'),
        ('/agent/calendar', 'Done and cancelled'),
        ('/agent/more', 'Your work'),
        ('/agent/listings', 'STUB /agent/listings'),
      ]) {
        await t.pumpWidget(app(start: path));
        await settle(t);
        expect(find.textContaining(marker), findsWidgets, reason: path);
        seen.add(marker);
      }
      expect(seen.length, 5);
    });

    testWidgets('a shopper is refused, not shown the agent screens', (t) async {
      phone(t);
      await t.pumpWidget(app(me: _buyer));
      await settle(t);
      expect(find.text('Your workspace'), findsNothing);
      expect(find.text('Contacts'), findsNothing);
    });

    testWidgets('dashboard numbers come from the records', (t) async {
      phone(t);
      await t.pumpWidget(app());
      await settle(t);
      final crm = box.read(agentCrmProvider);
      final fresh = crm.contacts.where((c) => c.status == LeadStatus.fresh).length;
      final open = crm.contacts.where((c) => c.status != LeadStatus.won && c.status != LeadStatus.lost).length;
      expect(find.bySemanticsLabel('New leads: $fresh'), findsOneWidget);
      expect(find.bySemanticsLabel('Open leads: $open'), findsOneWidget);
    });

    testWidgets('contacts: search and status filter change the list; open a contact', (t) async {
      phone(t);
      await t.pumpWidget(app(start: '/agent/contacts'));
      await settle(t);
      expect(find.text('8 contacts'), findsOneWidget);
      await t.enterText(find.byType(EditableText).first, 'layla');
      await settle(t);
      expect(find.text('1 contacts'), findsOneWidget);
      expect(find.text('Layla Demo'), findsOneWidget);
      expect(find.text('Omar Sample'), findsNothing);
      await t.enterText(find.byType(EditableText).first, '');
      await t.ensureVisible(find.widgetWithText(AQChoicePill, 'Won'));
      await t.tap(find.widgetWithText(AQChoicePill, 'Won'));
      await settle(t);
      expect(find.text('Khalid Placeholder'), findsOneWidget);
      expect(find.text('Layla Demo'), findsNothing);
      await t.tap(find.text('Khalid Placeholder'));
      await settle(t);
      expect(find.text('Lease signed. Thank-you note sent.'), findsOneWidget);
    });

    testWidgets('contact detail: note, status and edit update the same record', (t) async {
      phone(t);
      await t.pumpWidget(app(start: '/agent/contacts/C3'));
      await settle(t);
      expect(find.text('Huda Example'), findsWidgets);
      await t.enterText(find.byType(EditableText).first, 'Sent the brochure');
      await settle(t);
      await t.tap(find.text('Save note'));
      await settle(t);
      expect(find.text('Sent the brochure'), findsOneWidget);
      expect(box.read(agentCrmProvider).contacts.firstWhere((c) => c.id == 'C3').notes.first.text, 'Sent the brochure');
      await t.ensureVisible(find.text('Negotiating').first);
      await t.tap(find.text('Negotiating').first);
      await settle(t);
      expect(box.read(agentCrmProvider).contacts.firstWhere((c) => c.id == 'C3').status, LeadStatus.negotiating);
    });

    testWidgets('add contact: validation first, then the new contact exists', (t) async {
      phone(t);
      await t.pumpWidget(app(start: '/agent/contacts/new'));
      await settle(t);
      await t.tap(find.text('Save contact'));
      await settle(t);
      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter a phone number.'), findsOneWidget);
      final fields = find.byType(EditableText);
      await t.enterText(fields.at(0), 'Zainab Fictional');
      await t.enterText(fields.at(1), '90001234');
      await t.tap(find.text('Save contact'));
      await settle(t);
      expect(box.read(agentCrmProvider).contacts.first.name, 'Zainab Fictional');
      expect(find.text('Zainab Fictional'), findsWidgets);
    });

    testWidgets('calendar: tabs group appointments and an appointment can be finished', (t) async {
      phone(t);
      await t.pumpWidget(app(start: '/agent/calendar'));
      await settle(t);
      expect(find.text('Viewing with Omar Sample'), findsOneWidget);
      expect(find.text('Call Huda Example'), findsNothing, reason: 'that one is overdue');
      await t.tap(find.textContaining('Overdue ('));
      await settle(t);
      expect(find.text('Call Huda Example'), findsOneWidget);
      await t.tap(find.text('Call Huda Example'));
      await settle(t);
      expect(find.text('Mark done'), findsOneWidget);
      await t.tap(find.text('Mark done'));
      await settle(t);
      expect(box.read(agentCrmProvider).appointments.firstWhere((a) => a.id == 'A5').status, AppointmentStatus.done);
    });

    testWidgets('More offers the customer view and sign out, and no customer tab bar', (t) async {
      phone(t);
      await t.pumpWidget(app(start: '/agent/more'));
      await settle(t);
      expect(find.text('View as a customer'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      await t.tap(find.text('View as a customer'));
      await settle(t);
      expect(find.text('CUSTOMER HOME'), findsOneWidget);
    });

    for (final w in [320.0, 360.0, 412.0, 430.0, 1280.0]) {
      for (final dark in [false, true]) {
        testWidgets('every agent page fits at ${w.toInt()} px ${dark ? 'dark' : 'light'}', (t) async {
          phone(t, w: w, h: w > 900 ? 900 : 800);
          for (final p in ['/agent', '/agent/contacts', '/agent/contacts/C1', '/agent/contacts/new', '/agent/calendar', '/agent/more']) {
            await t.pumpWidget(app(start: p, dark: dark));
            await settle(t);
            expect(t.takeException(), isNull, reason: '$p @ $w');
          }
        });
      }
    }

    testWidgets('Arabic RTL and 200% text do not overflow', (t) async {
      phone(t, w: 360, h: 800);
      for (final p in ['/agent', '/agent/contacts', '/agent/contacts/C1', '/agent/calendar', '/agent/more']) {
        await t.pumpWidget(app(start: p, rtl: true));
        await settle(t);
        expect(t.takeException(), isNull, reason: 'rtl $p');
        await t.pumpWidget(app(start: p, scale: 2));
        await settle(t);
        expect(t.takeException(), isNull, reason: 'x2 $p');
      }
    });

    testWidgets('wide screens get a side rail instead of the bottom bar', (t) async {
      phone(t, w: 1280, h: 900);
      await t.pumpWidget(app());
      await settle(t);
      expect(find.text('AQARATI'), findsOneWidget);
      await t.tap(find.text('Contacts'));
      await settle(t);
      expect(find.text('Search name, place or interest'), findsOneWidget);
    });
  });

  test('which tab a location selects', () {
    expect(agentTabFor('/agent'), 0);
    expect(agentTabFor('/agent/listings/new'), 1);
    expect(agentTabFor('/agent/contacts/C1'), 2);
    expect(agentTabFor('/agent/calendar'), 3);
    expect(agentTabFor('/agent/analytics'), 4);
    expect(agentTabFor('/agent/leads'), 5);
    expect(agentTabFor('/workspace/enquiries'), 5);
  });
}
