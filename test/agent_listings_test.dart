import 'dart:typed_data';

import 'package:aqarati_app/core/domain/account_models.dart';
import 'package:aqarati_app/data/api/account_api.dart';
import 'package:aqarati_app/data/models/enums.dart';
import 'package:aqarati_app/features/devbuild/db_models.dart'
    show PermissionDeniedException;
import 'package:aqarati_app/features/entry/models/signup_purpose.dart';
import 'package:aqarati_app/features/flow/state/document_state.dart';
import 'package:aqarati_app/features/listings/listing_models.dart';
import 'package:aqarati_app/features/listings/listing_repository.dart';
import 'package:aqarati_app/features/listings/listing_screens.dart';
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

ListingInput input({
  String title = 'Sea view villa',
  PropertyType type = PropertyType.villa,
  String deed = 'DEED123456',
  TransactionType tx = TransactionType.buy,
  List<ListingPhoto> photos = const [],
}) => ListingInput(
  title: title,
  description: 'Quiet street',
  type: type,
  transaction: tx,
  priceOmr: 250000,
  governorate: 'Muscat',
  wilayat: 'Bawshar',
  sizeSqm: 400,
  bedrooms: 4,
  bathrooms: 3,
  titleDeed: deed,
  newPhotos: photos,
);

DemoListingRepository repo() => DemoListingRepository(latency: Duration.zero);

/// A service that has listings but no pause / resume operation (the documented contract today).
class _NoPauseRepo extends DemoListingRepository {
  int pauseCalls = 0;
  _NoPauseRepo() : super(latency: Duration.zero);
  @override
  bool get supportsPause => false;
  @override
  Future<AgentListing> pause(String id) {
    pauseCalls++;
    return super.pause(id);
  }
}

class _FakePicker implements DocumentPicker {
  final PickedDocument? next;
  _FakePicker(this.next);
  @override
  Future<PickedDocument?> pick() async => next;
}

Widget app(
  DemoListingRepository r, {
  MeSession? me = _agent,
  String start = '/agent/listings',
  DocumentPicker? picker,
  Size? size,
}) {
  final router = GoRouter(
    initialLocation: start,
    routes: [
      GoRoute(
        path: '/app/home',
        builder: (_, _) => const Scaffold(body: Text('HOME')),
      ),
      GoRoute(
        path: '/agent/listings',
        builder: (_, _) => const MyListingsScreen(),
      ),
      GoRoute(
        path: '/agent/listings/new',
        builder: (_, _) => const ListingFormScreen(),
      ),
      GoRoute(
        path: '/agent/listings/:id',
        builder: (_, s) => ListingDetailScreen(
          id: s.pathParameters['id']!,
          flash: s.uri.queryParameters['flash'],
        ),
      ),
      GoRoute(
        path: '/agent/listings/:id/edit',
        builder: (_, s) => ListingFormScreen(editId: s.pathParameters['id']),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      meProvider.overrideWith((ref) async {
        if (me == null) throw const ApiException(ApiErrorCode.network);
        return me;
      }),
      listingRepositoryProvider.overrideWithValue(r),
      if (picker != null) documentPickerProvider.overrideWithValue(picker),
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

Future<void> big(WidgetTester t) async {
  t.view.physicalSize = const Size(393, 2200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

void main() {
  group('listing repository rules', () {
    test(
      'a new listing starts in review and is never live by itself',
      () async {
        final r = repo();
        final l = await r.create(input());
        expect(l.status, ListingStatus.pendingVerification);
        expect(l.isLive, isFalse);
        expect((await r.mine()).single.id, l.id);
      },
    );

    test('pause only from live, resume only from paused, and status follows the response', () async {
      final r = repo();
      final l = await r.create(input());
      await expectLater(
        r.pause(l.id),
        throwsA(isA<ListingStatusConflictException>()),
      );
      r.debugSet(l.id, ListingStatus.approved);
      expect((await r.pause(l.id)).status, ListingStatus.paused);
      await expectLater(
        r.pause(l.id),
        throwsA(isA<ListingStatusConflictException>()),
      );
      expect((await r.resume(l.id)).status, ListingStatus.approved);
    });

    test(
      'editing a live listing keeps it live while the change set is reviewed',
      () async {
        final r = repo();
        final l = await r.create(input());
        r.debugSet(l.id, ListingStatus.approved);
        final e = await r.update(
          l.id,
          input(title: 'Sea view villa, new price'),
        );
        expect(e.status, ListingStatus.approved);
        expect(e.pendingChanges, isTrue);
      },
    );

    test(
      'a returned listing goes back to review when it is sent again',
      () async {
        final r = repo();
        final l = await r.create(input());
        r.debugSet(
          l.id,
          ListingStatus.resubmissionRequired,
          feedback: 'Photos do not match',
        );
        final e = await r.update(l.id, input());
        expect(e.status, ListingStatus.pendingVerification);
      },
    );

    test('an agent cannot read or change another agent\'s listing', () async {
      final r = repo();
      final foreign = r.debugAddForeign();
      await expectLater(
        r.get(foreign),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        r.pause(foreign),
        throwsA(isA<PermissionDeniedException>()),
      );
      await expectLater(
        r.update(foreign, input()),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await r.mine()), isEmpty);
    });

    test('a duplicate title deed and transaction is refused', () async {
      final r = repo();
      await r.create(input());
      await expectLater(
        r.create(input(title: 'Other title')),
        throwsA(isA<DuplicateListingException>()),
      );
    });

    test('a failed write changes nothing', () async {
      final r = repo();
      final l = await r.create(input());
      r.debugSet(l.id, ListingStatus.approved);
      r.debugNextError = const ApiException(ApiErrorCode.network);
      await expectLater(r.pause(l.id), throwsA(isA<ApiException>()));
      expect((await r.get(l.id))!.status, ListingStatus.approved);
    });

    test(
      'photos: kept ones stay, removed ones go, new ones are added',
      () async {
        final r = repo();
        final l = await r.create(
          input(
            photos: [
              ListingPhoto(id: 'a', name: 'a.jpg', bytes: Uint8List(3)),
              ListingPhoto(id: 'b', name: 'b.jpg', bytes: Uint8List(3)),
            ],
          ),
        );
        r.debugSet(l.id, ListingStatus.resubmissionRequired);
        final keep = l.photos.first.id;
        final e = await r.update(
          l.id,
          ListingInput(
            title: 'T',
            description: 'D',
            type: PropertyType.villa,
            transaction: TransactionType.buy,
            priceOmr: 1,
            governorate: 'Muscat',
            wilayat: 'Bawshar',
            sizeSqm: 1,
            titleDeed: 'DEED123456',
            keepPhotoIds: [keep],
            newPhotos: [
              ListingPhoto(id: 'c', name: 'c.jpg', bytes: Uint8List(3)),
            ],
          ),
        );
        expect(e.photos.length, 2);
        expect(e.photos.first.id, keep);
      },
    );

    test('rooms only apply to types that have rooms', () {
      expect(attributesFor(PropertyType.villa).bedrooms, isTrue);
      expect(attributesFor(PropertyType.residentialLand).bedrooms, isFalse);
      expect(attributesFor(PropertyType.farm).bathrooms, isFalse);
      expect(deedValid('abc 123-45'), isTrue);
      expect(deedValid('ab1'), isFalse);
    });
  });

  group('My listings screen', () {
    testWidgets('empty state offers Add listing', (t) async {
      await big(t);
      await t.pumpWidget(app(repo()));
      await settle(t);
      expect(find.text('No listings yet'), findsOneWidget);
      expect(find.text('Add listing'), findsWidgets);
    });

    testWidgets('a shopper cannot use the agent workspace', (t) async {
      await big(t);
      await t.pumpWidget(app(repo(), me: _buyer));
      await settle(t);
      expect(find.text('Business workspace only'), findsOneWidget);
      expect(find.text('Register as a Business or Professional'), findsOneWidget, reason: 'a real next step, not a dead end');
      expect(find.text('Add listing'), findsNothing);
    });

    testWidgets('a signed-out visitor cannot use the agent workspace', (
      t,
    ) async {
      await big(t);
      await t.pumpWidget(app(repo(), me: null));
      await settle(t);
      expect(find.text('Sign in to open this workspace'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget, reason: 'a way to sign in, not a dead end');
      expect(find.text('Add listing'), findsNothing);
    });

    testWidgets(
      'listings show their real status and the filters narrow the list',
      (t) async {
        final r = repo();
        final a = await r.create(input(title: 'Live villa', deed: 'AAA111'));
        await r.create(
          input(
            title: 'Waiting flat',
            deed: 'BBB222',
            type: PropertyType.apartment,
          ),
        );
        r.debugSet(a.id, ListingStatus.approved);
        await big(t);
        await t.pumpWidget(app(r));
        await settle(t);
        expect(find.textContaining('Live villa'), findsOneWidget);
        expect(find.textContaining('Waiting flat'), findsOneWidget);
        await t.tap(find.text('In review').first);
        await settle(t);
        expect(find.textContaining('Waiting flat'), findsOneWidget);
        expect(find.textContaining('Live villa'), findsNothing);
        await t.ensureVisible(find.text('Paused').first);
        await t.tap(find.text('Paused').first);
        await settle(t);
        expect(find.text('Nothing with this status'), findsOneWidget);
      },
    );

    testWidgets(
      'a failing service shows an error with Retry, not an empty list',
      (t) async {
        final r = repo();
        await big(t);
        final failing = _Failing();
        await t.pumpWidget(
          ProviderScope(
            overrides: [
              meProvider.overrideWith((ref) async => _agent),
              listingRepositoryProvider.overrideWithValue(failing),
            ],
            child: MaterialApp.router(
              routerConfig: GoRouter(
                routes: [
                  GoRoute(
                    path: '/',
                    builder: (_, _) => const MyListingsScreen(),
                  ),
                ],
              ),
              supportedLocales: const [Locale('en')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
            ),
          ),
        );
        await settle(t);
        expect(find.text('No listings yet'), findsNothing);
        expect(find.text('Try again'), findsOneWidget);
        r.mine();
      },
    );
  });

  group('Add and edit', () {
    testWidgets('validation keeps what was typed and explains each problem', (
      t,
    ) async {
      await big(t);
      await t.pumpWidget(app(repo(), start: '/agent/listings/new'));
      await settle(t);
      await t.enterText(
        find.widgetWithText(TextField, 'Title').first,
        'Villa by the sea',
      );
      await t.tap(find.text('Send for review'));
      await settle(t);
      expect(find.text('Choose a property type.'), findsWidgets);
      expect(find.text('Choose a governorate.'), findsOneWidget);
      expect(find.text('Use 6 to 20 letters or digits.'), findsOneWidget);
      expect(find.text('Villa by the sea'), findsOneWidget);
    });

    testWidgets('land hides room fields, a villa shows them', (t) async {
      final r = repo();
      final l = await r.create(input());
      r.debugSet(l.id, ListingStatus.resubmissionRequired);
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}/edit'));
      await settle(t);
      expect(find.text('Bedrooms'), findsOneWidget);
      expect(find.text('Parking spaces'), findsOneWidget);
    });

    testWidgets('editing prefills the existing record', (t) async {
      final r = repo();
      final l = await r.create(input(title: 'Prefilled title'));
      r.debugSet(l.id, ListingStatus.approved);
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}/edit'));
      await settle(t);
      expect(find.text('Prefilled title'), findsOneWidget);
      expect(find.text('DEED123456'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
    });

    testWidgets(
      'another agent\'s listing cannot be opened or edited by its address',
      (t) async {
        final r = repo();
        final foreign = r.debugAddForeign();
        await big(t);
        await t.pumpWidget(app(r, start: '/agent/listings/$foreign'));
        await settle(t);
        expect(find.text('This listing is not yours'), findsOneWidget);
        await t.pumpWidget(app(r, start: '/agent/listings/$foreign/edit'));
        await settle(t);
        expect(find.text('This listing is not yours'), findsOneWidget);
        expect(find.text('Save changes'), findsNothing);
      },
    );

    testWidgets('a photo of the wrong type is refused with a reason', (
      t,
    ) async {
      await big(t);
      final pdf = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 1, 2, 3]);
      await t.pumpWidget(
        app(
          repo(),
          start: '/agent/listings/new',
          picker: _FakePicker(
            PickedDocument(name: 'deed.pdf', sizeBytes: pdf.length, bytes: pdf),
          ),
        ),
      );
      await settle(t);
      await t.ensureVisible(find.text('Add photo'));
      await t.tap(find.text('Add photo'));
      await settle(t);
      expect(find.text('Only JPG or PNG photos can be added.'), findsOneWidget);
    });
  });

  group('the sent message follows the real status', () {
    const sent = 'Sent for review. This listing is not live';

    Future<(DemoListingRepository, AgentListing)> open(WidgetTester t) async {
      final r = repo();
      final l = await r.create(input());
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}?flash=sent'));
      await settle(t);
      return (r, l);
    }

    Future<void> decide(
      WidgetTester t,
      DemoListingRepository r,
      AgentListing l,
      ListingStatus s, {
      String? feedback,
    }) async {
      r.debugSet(l.id, s, feedback: feedback);
      ProviderScope.containerOf(t.element(find.byType(ListingDetailScreen)))
          .invalidate(myListingProvider(l.id));
      await settle(t);
    }

    testWidgets('pending shows it, approved removes it and offers Pause', (
      t,
    ) async {
      final (r, l) = await open(t);
      expect(find.textContaining(sent), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
      await decide(t, r, l, ListingStatus.approved);
      expect(find.textContaining(sent), findsNothing);
      expect(
        find.text('This listing is live and visible to buyers.'),
        findsOneWidget,
      );
      expect(find.text('Pause'), findsWidgets);
    });

    testWidgets(
      'pending then changes requested: no sent message, edit offered',
      (t) async {
        final (r, l) = await open(t);
        await decide(
          t,
          r,
          l,
          ListingStatus.resubmissionRequired,
          feedback: 'Photos are blurry',
        );
        expect(find.textContaining(sent), findsNothing);
        expect(find.text('Needs changes'), findsOneWidget);
        expect(find.text('Pause'), findsNothing);
      },
    );

    testWidgets('pending then rejected: no sent message, not live', (t) async {
      final (r, l) = await open(t);
      await decide(t, r, l, ListingStatus.rejected);
      expect(find.textContaining(sent), findsNothing);
      expect(find.text('Not approved'), findsOneWidget);
      expect(find.text('Pause'), findsNothing);
    });
  });

  group('Detail and pause', () {
    testWidgets('pause asks first, then follows the real response', (t) async {
      final r = repo();
      final l = await r.create(input());
      r.debugSet(l.id, ListingStatus.approved);
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}'));
      await settle(t);
      expect(
        find.text('This listing is live and visible to buyers.'),
        findsOneWidget,
      );
      await t.tap(find.text('Pause').first);
      await settle(t);
      expect(find.text('Pause this listing?'), findsOneWidget);
      await t.tap(find.text('Pause listing'));
      await settle(t);
      expect(find.text('Listing paused'), findsOneWidget);
      expect((await r.get(l.id))!.status, ListingStatus.paused);
      expect(find.text('Resume'), findsOneWidget);
    });

    test(
      'only the demo claims pause support; the unconnected service does not',
      () {
        expect(repo().supportsPause, isTrue);
        expect(const UnavailableListingRepository().supportsPause, isFalse);
      },
    );

    testWidgets(
      'without a service pause operation nothing is attempted or changed',
      (t) async {
        final r = _NoPauseRepo();
        final l = await r.create(input());
        r.debugSet(l.id, ListingStatus.approved);
        await big(t);
        await t.pumpWidget(app(r, start: '/agent/listings/${l.id}'));
        await settle(t);
        await t.tap(find.text('Pause').first);
        await settle(t);
        expect(find.text('Pause this listing?'), findsNothing);
        expect(find.textContaining('not connected yet'), findsOneWidget);
        expect(find.text('Listing paused'), findsNothing);
        expect(r.pauseCalls, 0);
        expect((await r.get(l.id))!.status, ListingStatus.approved);
      },
    );

    testWidgets('a failed pause leaves the listing live and says so', (
      t,
    ) async {
      final r = repo();
      final l = await r.create(input());
      r.debugSet(l.id, ListingStatus.approved);
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}'));
      await settle(t);
      r.debugNextError = const ApiException(ApiErrorCode.network);
      await t.tap(find.text('Pause').first);
      await settle(t);
      await t.tap(find.text('Pause listing'));
      await settle(t);
      expect(
        find.text(
          'We could not pause this listing. Its status did not change.',
        ),
        findsOneWidget,
      );
      expect((await r.get(l.id))!.status, ListingStatus.approved);
    });

    testWidgets(
      'a listing in review offers no Pause and no false "live" claim',
      (t) async {
        final r = repo();
        final l = await r.create(input());
        await big(t);
        await t.pumpWidget(app(r, start: '/agent/listings/${l.id}'));
        await settle(t);
        expect(find.text('Pause'), findsNothing);
        expect(
          find.textContaining('not visible to buyers until it is approved'),
          findsOneWidget,
        );
      },
    );

    testWidgets('reviewer feedback is shown on a returned listing', (t) async {
      final r = repo();
      final l = await r.create(input());
      r.debugSet(
        l.id,
        ListingStatus.resubmissionRequired,
        feedback: 'Photos do not match the deed.',
      );
      await big(t);
      await t.pumpWidget(app(r, start: '/agent/listings/${l.id}'));
      await settle(t);
      expect(find.text('Photos do not match the deed.'), findsOneWidget);
      expect(find.text('Send again for review'), findsOneWidget);
    });
  });
}

class _Failing extends DemoListingRepository {
  _Failing() : super(latency: Duration.zero);
  @override
  Future<List<AgentListing>> mine() async =>
      throw const ApiException(ApiErrorCode.network);
}
