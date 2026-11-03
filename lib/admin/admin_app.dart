import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/aq/aq_scene.dart';
import '../core/aq/aq_tokens.dart';
import '../core/localization/entry_strings.dart' show localeProvider;
import '../core/theme/app_theme.dart';
import '../features/ads/ad_repository.dart';
import 'admin_ads_screens.dart';
import 'admin_l10n.dart' show AdminLang;
import 'admin_auth.dart';
import 'admin_auth_screens.dart';
import 'admin_directory_screens.dart';
import 'admin_models.dart';
import 'admin_modules.dart';
import 'admin_moderation_screens.dart';
import 'admin_repository.dart';
import 'admin_verification_screens.dart';

/// Keeps the router in step with the sign-in stage, so a sign-out or an ended session leaves every
/// protected page at once.
class AdminAuthListenable extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// Where the sign-in stage allows the person to be. Nothing protected is reachable before the code
/// step is done, whatever address is typed.
String? adminRedirect(AdminAuthStage stage, String location) {
  final onLogin = location == '/login';
  final onCode = location == '/code';
  switch (stage) {
    case AdminAuthStage.signedOut:
      return onLogin ? null : '/login';
    case AdminAuthStage.needsTotp:
      return onCode ? null : '/code';
    case AdminAuthStage.active:
      if (onLogin || onCode || location == '/') return '/overview';
      return null;
  }
}

GoRouter buildAdminRouter(WidgetRef ref, AdminAuthListenable listenable) {
  Page<void> page(GoRouterState s, Widget child) =>
      AQRoute.fade(key: s.pageKey, child: child);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: listenable,
    redirect: (context, state) =>
        adminRedirect(ref.read(adminAuthProvider).stage, state.uri.path),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/overview'),
      // Hosted at #/admin, the console starts from the browser's own path; send it to the root.
      GoRoute(path: '/admin', redirect: (_, _) => '/'),
      GoRoute(
        path: '/overview',
        pageBuilder: (c, s) => page(s, const AdminOverviewScreen()),
      ),
      GoRoute(
        path: '/accounts',
        pageBuilder: (c, s) => page(s, const AdminAccountsScreen()),
      ),
      GoRoute(
        path: '/accounts/:id',
        pageBuilder: (c, s) =>
            page(s, AdminAccountDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/reports',
        pageBuilder: (c, s) => page(s, const AdminReportsScreen()),
      ),
      GoRoute(
        path: '/reports/:id',
        pageBuilder: (c, s) =>
            page(s, AdminReportDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/m/:key',
        pageBuilder: (c, s) {
          final k = ModKey.values.where((x) => x.name == s.pathParameters['key']).firstOrNull;
          return page(s, k == null ? const AdminOverviewScreen() : AdminModuleListScreen(modKey: k));
        },
      ),
      GoRoute(
        path: '/m/:key/:id',
        pageBuilder: (c, s) {
          final k = ModKey.values.where((x) => x.name == s.pathParameters['key']).firstOrNull;
          return page(s, k == null ? const AdminOverviewScreen() : AdminModuleDetailScreen(modKey: k, id: s.pathParameters['id']!));
        },
      ),
      GoRoute(path: '/analytics', pageBuilder: (c, s) => page(s, const AdminAnalyticsScreen())),
      GoRoute(path: '/settings', pageBuilder: (c, s) => page(s, const AdminSettingsScreen())),
      GoRoute(
        path: '/audit',
        pageBuilder: (c, s) => page(s, const AdminAuditScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (c, s) => page(s, const AdminLoginScreen()),
      ),
      GoRoute(
        path: '/code',
        pageBuilder: (c, s) => page(s, const AdminTotpScreen()),
      ),
      GoRoute(
        path: '/verification',
        pageBuilder: (c, s) => page(s, const VerificationQueueScreen()),
      ),
      GoRoute(
        path: '/verification/:id',
        pageBuilder: (c, s) =>
            page(s, VerificationDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/moderation',
        pageBuilder: (c, s) => page(s, const ModerationQueueScreen()),
      ),
      GoRoute(
        path: '/moderation/:id',
        pageBuilder: (c, s) =>
            page(s, ModerationDetailScreen(id: s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/ads',
        pageBuilder: (c, s) => page(s, const AdsListScreen()),
      ),
      GoRoute(
        path: '/ads/new',
        pageBuilder: (c, s) => page(s, const AdFormScreen()),
      ),
      GoRoute(
        path: '/ads/:id/edit',
        pageBuilder: (c, s) =>
            page(s, AdFormScreen(editId: s.pathParameters['id'])),
      ),
    ],
  );
}

/// A route provider that never writes to the browser address. Used when the console is hosted at
/// `#/admin`: the outer router owns the address, and this inner one must not overwrite it, or a
/// refresh would land outside the console.
class _QuietRouteInformationProvider extends RouteInformationProvider with ChangeNotifier {
  _QuietRouteInformationProvider(this._inner) {
    _inner.addListener(notifyListeners);
  }
  final RouteInformationProvider _inner;

  @override
  RouteInformation get value => _inner.value;

  @override
  void routerReportsNewRouteInformation(RouteInformation routeInformation, {RouteInformationReportingType type = RouteInformationReportingType.none}) {}

  @override
  void dispose() {
    _inner.removeListener(notifyListeners);
    super.dispose();
  }
}

/// The admin console. It shares the design system, motion and components with the customer app and
/// ships as its own build; the customer app never imports this file.
class AdminApp extends ConsumerStatefulWidget {
  const AdminApp({super.key});
  @override
  ConsumerState<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends ConsumerState<AdminApp> {
  final _listenable = AdminAuthListenable();
  late final GoRouter _router = buildAdminRouter(ref, _listenable);

  /// Hosted inside the customer app, where the outer router owns the browser address (`#/admin`).
  late final bool _hosted = ref.read(adminExitProvider) != null;

  @override
  void dispose() {
    _router.dispose();
    _listenable.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminAuthProvider, (_, _) => _listenable.ping());
    // The console follows the app's own language switch. The strings are looked up while building,
    // so the whole tree is rebuilt (keyed below) when the language changes.
    final locale = ref.watch(localeProvider);
    AdminLang.ar = locale.languageCode == 'ar';
    return MaterialApp.router(
      title: 'AQARATI Admin',
      locale: locale,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF1A1613),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF825C3F),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.light,
      routeInformationProvider: _hosted
          ? _QuietRouteInformationProvider(_router.routeInformationProvider)
          : _router.routeInformationProvider,
      routeInformationParser: _router.routeInformationParser,
      routerDelegate: _router.routerDelegate,
      backButtonDispatcher: _router.backButtonDispatcher,
      builder: (context, child) => KeyedSubtree(
        key: ValueKey(locale.languageCode),
        child: AQThemeTransition(
          mode: ThemeMode.light,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}

/// Provider overrides for a console that runs against the demo store: one store feeds sign-in, the
/// queues, the moderation list and the ad management, and the ads the customer side would be served.
List<Override> adminOverrides(DemoAdminStore store) => [
  adminStoreProvider.overrideWithValue(store),
  adRepositoryProvider.overrideWithValue(store.ads),
];
