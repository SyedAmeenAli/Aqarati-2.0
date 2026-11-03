import 'package:aqarati_app/admin/admin_app.dart';
import 'package:aqarati_app/admin/admin_directory_screens.dart';
import 'package:aqarati_app/admin/admin_l10n.dart';
import 'package:aqarati_app/admin/admin_modules.dart';
import 'package:aqarati_app/admin/admin_repository.dart';
import 'package:aqarati_app/admin/admin_ui.dart' show AdminIconButton;
import 'package:aqarati_app/core/localization/entry_strings.dart' show localeProvider;
import 'package:aqarati_app/features/ads/ad_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

DemoAdminStore store() => DemoAdminStore(latency: Duration.zero, ads: DemoAdRepository(latency: Duration.zero));

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

void size(WidgetTester t, double w, [double h = 1000]) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
}

Widget app(DemoAdminStore s, {bool ar = true}) => ProviderScope(
  overrides: [...adminOverrides(s), if (ar) localeProvider.overrideWith((ref) => const Locale('ar'))],
  child: const AdminApp(),
);

Future<void> signIn(WidgetTester t, String who) async {
  await t.enterText(find.byType(TextField).at(0), '$who@demo.test');
  await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
  await t.tap(find.text('متابعة'));
  await settle(t);
  await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
  await settle(t);
}

final _latin = RegExp(r'[A-Za-z]');
final _arabic = RegExp(r'[؀-ۿ]');

/// Text on screen that still reads as English: it has Latin letters and no Arabic. Isolated names
/// (VFmt.iso), e-mail addresses, money and identifiers are data and are allowed.
Set<String> latinLeft(WidgetTester t) {
  final out = <String>{};
  void visit(RenderObject r) {
    final InlineSpan? span = r is RenderParagraph ? r.text : (r is RenderEditable ? r.text : null);
    if (span != null) {
      final txt = span.toPlainText(includePlaceholders: false).replaceAll(RegExp('[\u2066-\u2069]'), '').trim();
      final iconFont = span.style?.fontFamily?.contains('Icons') ?? false;
      if (!iconFont && txt.isNotEmpty && _latin.hasMatch(txt) && !_arabic.hasMatch(txt)) out.add(txt);
    }
    r.visitChildren(visit);
  }

  visit(t.binding.renderViews.first);
  return out;
}

/// Labels a screen reader would speak that are still English (the visible text can be Arabic while
/// a Semantics label is not).
Set<String> semLeft(WidgetTester t) {
  final out = <String>{};
  for (final n in t.semantics.simulatedAccessibilityTraversal()) {
    final txt = n.label.replaceAll(RegExp('[\u2066-\u2069]'), '').trim();
    if (txt.isNotEmpty && _latin.hasMatch(txt) && !_arabic.hasMatch(txt)) out.add(txt);
  }
  return out;
}

void main() {
  testWidgets('Arabic: every console screen is fully translated and mirrored', (t) async {
    final sem = t.ensureSemantics();
    size(t, 1300);
    AdminLang.missing.clear();
    final s = store()..seedDemoRecords();
    await t.pumpWidget(app(s));
    await settle(t);
    // Sign-in is Arabic and right-to-left.
    expect(Directionality.of(t.element(find.byType(Scaffold).first)), TextDirection.rtl);
    expect(find.text('تسجيل الدخول'), findsWidgets);
    await signIn(t, 'super');
    expect(find.byType(AdminOverviewScreen), findsOneWidget);

    final router = GoRouter.of(t.element(find.byType(AdminOverviewScreen)));
    final left = <String, String>{};
    final paths = <String>[
      '/overview', '/accounts', '/accounts/U1', '/accounts/G1', '/accounts/D1', '/verification', '/moderation', '/ads', '/ads/new',
      '/reports', '/reports/R1', '/reports/R3', '/audit', '/analytics', '/settings',
      for (final k in ModKey.values) ...['/m/${k.name}'],
    ];
    for (final p in paths) {
      router.go(p);
      await settle(t);
      expect(t.takeException(), isNull, reason: p);
      for (final x in {...latinLeft(t), ...semLeft(t)}) {
        left.putIfAbsent(x, () => p);
      }
    }
    // The first record of every module, so each detail screen is covered.
    final seed = seedModules();
    for (final k in ModKey.values) {
      router.go('/m/${k.name}/${seed[k]!.first.id}');
      await settle(t);
      expect(t.takeException(), isNull, reason: k.name);
      for (final x in latinLeft(t)) {
        left.putIfAbsent(x, () => '/m/${k.name}/detail');
      }
    }
    for (final v in await s.list()) {
      router.go('/verification/${v.id}');
      await settle(t);
      for (final x in latinLeft(t)) {
        left.putIfAbsent(x, () => '/verification/detail');
      }
    }
    for (final l in await s.listListings()) {
      router.go('/moderation/${l.id}');
      await settle(t);
      for (final x in latinLeft(t)) {
        left.putIfAbsent(x, () => '/moderation/detail');
      }
    }
    final names = RegExp(r'^(R\d+|English|[A-Z][a-z]+( [A-Z][a-z]+)*|.*example\.test|.*\.pdf|OMR [\d,]+|\d+ m²|.*(Muscat|Bawshar|Salalah|Ruwi|Khoud|Mouj)|.*\(e-Broker\)|https://.*|4-Bedroom Villa.*|Residential Plot.*|Modern Family Villa.*|Office floor.*|Duplicate studio flat|Al .*)$');
    final real = {for (final e in left.entries) if (!names.hasMatch(e.value == '' ? '' : e.key)) e.key: e.value};
    expect(real, isEmpty, reason: 'English text still on screen in Arabic: $real');
    sem.dispose();
    expect(AdminLang.missing, isEmpty, reason: 'untranslated: ${AdminLang.missing.toList()..sort()}');
  });

  testWidgets('Arabic: sign-in, one-time code, validation, dialogs, empty and read-only states', (t) async {
    size(t, 1300);
    AdminLang.missing.clear();
    final s = store();
    final left = <String, String>{};
    void sweep(String where) {
      for (final x in latinLeft(t)) {
        left.putIfAbsent(x, () => where);
      }
    }

    await t.pumpWidget(app(s));
    await settle(t);
    // Empty submit shows the Arabic field errors.
    await t.tap(find.text('متابعة'));
    await settle(t);
    expect(find.text('أدخل بريدك الإلكتروني الإداري.'), findsOneWidget);
    expect(find.text('أدخل كلمة المرور.'), findsOneWidget);
    sweep('login errors');
    // A wrong password gets the Arabic answer.
    await t.enterText(find.byType(TextField).at(0), 'nobody@demo.test');
    await t.enterText(find.byType(TextField).at(1), 'wrong-password');
    await t.tap(find.text('متابعة'));
    await settle(t);
    expect(find.text('البريد الإلكتروني أو كلمة المرور غير صحيحة.'), findsOneWidget);
    // Right credentials, then a wrong code.
    await t.enterText(find.byType(TextField).at(0), 'super@demo.test');
    await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
    await t.tap(find.text('متابعة'));
    await settle(t);
    expect(find.text('رمز لمرة واحدة'), findsWidgets);
    sweep('one-time code');
    await t.enterText(find.byType(TextField).first, '000000');
    await settle(t);
    expect(find.text('هذا الرمز غير صحيح. أدخل الرمز الحالي.'), findsOneWidget);
    await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
    await settle(t);
    expect(find.byType(AdminOverviewScreen), findsOneWidget);
    sweep('overview');
    final router = GoRouter.of(t.element(find.byType(AdminOverviewScreen)));

    // Empty search state.
    router.go('/accounts');
    await settle(t);
    await t.enterText(find.byType(TextField).first, 'zzzzzz');
    await settle(t);
    expect(find.text('لا توجد حسابات مطابقة'), findsOneWidget);
    sweep('accounts empty');

    // A module action opens a confirmation dialog in Arabic.
    router.go('/m/listings/L1');
    await settle(t);
    await t.tap(find.text('إخفاء'));
    await settle(t);
    expect(find.byType(Dialog), findsOneWidget);
    sweep('confirm dialog');
    await t.tap(find.text('إلغاء').last);
    await settle(t);

    // Banner form: saving empty explains each missing field in Arabic.
    router.go('/ads/new');
    await settle(t);
    await t.ensureVisible(find.text('حفظ وإرسال للمراجعة'));
    await t.tap(find.text('حفظ وإرسال للمراجعة'));
    await settle(t);
    expect(find.text('أدخل اسم الراعي.'), findsWidgets);
    sweep('ad form errors');

    // Moderation with no records: Arabic empty state.
    router.go('/moderation');
    await settle(t);
    expect(find.text('لا توجد عقارات بانتظار المراجعة'), findsOneWidget);
    sweep('moderation empty');

    // Verification detail: the decision flow and the code dialog.
    s.seedDemoRecords();
    router.go('/verification');
    await settle(t);
    final first = (await s.list()).first;
    router.go('/verification/${first.id}');
    await settle(t);
    sweep('verification detail');
    expect(AdminLang.missing, isEmpty, reason: 'untranslated: ${AdminLang.missing.toList()..sort()}');
    final names = RegExp(r'^(R\d+|English|[A-Z][a-z]+( [A-Z][a-z]+)*|.*example\.test|.*\.pdf|Applicant .*|.*(Muscat|Bawshar|Salalah|Ruwi|Khoud|Mouj)|OMR [\d,]+|\d+ m²|z+|https://.*)$');
    final real = {for (final e in left.entries) if (!names.hasMatch(e.key)) e.key: e.value};
    expect(real, isEmpty, reason: 'English text still on screen in Arabic: $real');
  });

  testWidgets('the language button switches the whole console, and the app-wide locale with it', (t) async {
    size(t, 1300);
    final s = store();
    await t.pumpWidget(app(s, ar: false));
    await settle(t);
    await t.enterText(find.byType(TextField).at(0), 'super@demo.test');
    await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
    await t.tap(find.text('Continue'));
    await settle(t);
    await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
    await settle(t);
    final box = ProviderScope.containerOf(t.element(find.byType(AdminOverviewScreen)));
    expect(box.read(localeProvider).languageCode, 'en');
    expect(find.text('Overview'), findsWidgets);
    await t.tap(find.byKey(const ValueKey('admin-lang')));
    await settle(t);
    expect(box.read(localeProvider).languageCode, 'ar', reason: 'the same switch the rest of the app uses');
    expect(find.text('نظرة عامة'), findsWidgets);
    expect(find.text('Overview'), findsNothing);
    expect(Directionality.of(t.element(find.byType(AdminOverviewScreen))), TextDirection.rtl);
    await t.tap(find.byKey(const ValueKey('admin-lang')));
    await settle(t);
    expect(find.text('Overview'), findsWidgets);
    expect(Directionality.of(t.element(find.byType(AdminOverviewScreen))), TextDirection.ltr);
    expect(box.read(localeProvider).languageCode, 'en');
  });

  group('Arabic: right-to-left geometry', () {
    testWidgets('wide: the sidebar sits on the right, the page reads from the right, English is the mirror', (t) async {
      size(t, 1300);
      final s = store()..seedDemoRecords();
      Future<void> boot(bool ar) async {
        await t.pumpWidget(app(s, ar: ar));
        await settle(t);
        if (find.byType(AdminOverviewScreen).evaluate().isEmpty) {
          await t.enterText(find.byType(TextField).at(0), 'super@demo.test');
          await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
          await t.tap(find.text(ar ? 'متابعة' : 'Continue'));
          await settle(t);
          await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
          await settle(t);
        }
      }

      await boot(true);
      final navAr = t.getTopRight(find.text('نظرة عامة').first);
      final signOutAr = t.getTopRight(find.text('تسجيل الخروج').first);
      expect(navAr.dx, greaterThan(1300 - 300), reason: 'navigation is on the right');
      expect(signOutAr.dx, lessThan(1300), reason: 'sign-out is inside the sidebar');
      // The page heading starts at the right edge of the content column.
      router(t).go('/accounts');
      await settle(t);
      final titleAr = t.getTopRight(find.text('الحسابات والمهنيون').first);
      expect(titleAr.dx, greaterThan(1300 / 2), reason: 'heading is right-aligned');
      // A table row: the name column is first from the right, the joined date last.
      final nameHeader = t.getCenter(find.text('الاسم').first);
      final joinedHeader = t.getCenter(find.text('تاريخ الانضمام').first);
      expect(nameHeader.dx, greaterThan(joinedHeader.dx), reason: 'columns run right to left');
      // The back chevron points the right way in a detail page.
      router(t).go('/accounts/U1');
      await settle(t);
      expect(find.text('العودة إلى الحسابات'), findsWidgets);
      final backAr = t.getTopRight(find.text('العودة إلى الحسابات').first);
      expect(backAr.dx, greaterThan(1300 / 2), reason: 'Back is at the right edge in Arabic');
    });

    testWidgets('English control: the sidebar is on the left', (t) async {
      size(t, 1300);
      final s = store();
      await t.pumpWidget(app(s, ar: false));
      await settle(t);
      await t.enterText(find.byType(TextField).at(0), 'super@demo.test');
      await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
      await t.tap(find.text('Continue'));
      await settle(t);
      await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
      await settle(t);
      expect(t.getTopLeft(find.text('Overview').first).dx, lessThan(300));
    });

    testWidgets('narrow: the menu button and the language button sit on the correct sides, no overflow', (t) async {
      for (final w in [320.0, 390.0, 768.0]) {
        size(t, w, 900);
        final s = store();
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(app(s));
        await settle(t);
        await t.enterText(find.byType(TextField).at(0), 'super@demo.test');
        await t.enterText(find.byType(TextField).at(1), DemoAdminStore.demoPassword);
        await t.tap(find.text('متابعة'));
        await settle(t);
        await t.enterText(find.byType(TextField).first, DemoAdminStore.demoCode);
        await settle(t);
        expect(t.takeException(), isNull, reason: 'width $w');
        if (w < 600) {
          final menu = t.getCenter(find.byWidgetPredicate((w) => w is AdminIconButton && w.icon == 'menu').first);
          expect(menu.dx, greaterThan(w / 2), reason: 'the menu button is at the right edge at $w');
        } else {
          // Tablet: a navigation rail on the reading-start (right) edge instead of a menu button.
          expect(t.getCenter(find.text('المزيد')).dx, greaterThan(w / 2), reason: 'the rail is on the right in Arabic at $w');
        }
        final lang = t.getCenter(find.byKey(const ValueKey('admin-lang')).first);
        expect(lang.dx, lessThan(w / 2), reason: 'the language button is at the far end (left) at $w');
        for (final p in ['/accounts', '/verification', '/ads', '/m/listings', '/analytics', '/settings']) {
          router(t).go(p);
          await settle(t);
          expect(t.takeException(), isNull, reason: '$p at $w');
        }
      }
    });
  });
}

GoRouter router(WidgetTester t) => GoRouter.of(t.element(find.byType(Scaffold).first));
