import '../../features/account/profile_photo.dart';
import 'package:go_router/go_router.dart';

import '../../features/settings/settings_screens.dart';
import '../../features/account/buyer_profile.dart';
import '../../features/broker/broker_screens.dart';
import '../../features/ebroker/ebroker_screens.dart';
import '../../features/engagement/engagement_screens.dart';
import '../../features/reviews/review_flow_screens.dart';
import '../../features/reviews/review_models.dart' show ReviewTargetKind;
import '../../features/provider/provider_screens.dart';
import '../aq/aq_scene.dart' show AQRoute;

/// Routes added by the later feature modules (Aqary e-Broker, AqaratiBroker, provider workspace,
/// engagements and reviews, buyer profile). Kept apart so `app_router.dart` stays readable.
List<RouteBase> extraRoutes() => [
  GoRoute(
    path: '/business/:id/engage',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: EngageRequestScreen(
        professionalId: state.pathParameters['id']!,
        name: state.uri.queryParameters['name'] ?? '',
        type: state.uri.queryParameters['type'] ?? 'construction',
      ),
    ),
  ),
  GoRoute(
    path: '/review/:kind/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: WriteReviewScreen(
        kind: state.pathParameters['kind'] == 'provider'
            ? ReviewTargetKind.provider
            : ReviewTargetKind.professional,
        id: state.pathParameters['id']!,
        name: state.uri.queryParameters['name'] ?? '',
      ),
    ),
  ),
  GoRoute(
    path: '/provider',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const ProviderHomeScreen()),
  ),
  GoRoute(
    path: '/provider/invite',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: ProviderInviteScreen(code: state.uri.queryParameters['code']),
    ),
  ),
  GoRoute(
    path: '/provider/requests/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: ProviderRequestScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/sell/new',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const EBrokerFormScreen()),
  ),
  GoRoute(
    path: '/sell-new',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const EBrokerFormScreen()),
  ),
  GoRoute(
    path: '/sell/:id/edit',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: EBrokerFormScreen(editId: state.pathParameters['id']),
    ),
  ),
];

/// Customer screens hosted by the shared shell (they keep the bottom navigation).
List<RouteBase> extraShellRoutes() => [
  for (final name in kSettingsRoutes)
    GoRoute(
      path: '/app/account/settings/$name',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: settingsPageFor(name, kCustomerSettings),
      ),
    ),
  GoRoute(
    path: '/engagements',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const MyEngagementsScreen()),
  ),
  GoRoute(
    path: '/engagements/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: EngagementDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/reviews',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const MyReviewsScreen()),
  ),
  GoRoute(
    path: '/app/account/photo',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const ProfilePhotoScreen()),
  ),
  GoRoute(
    path: '/app/account/profile',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const BuyerProfileScreen()),
  ),
  GoRoute(
    path: '/app/account/profile/edit',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: const BuyerProfileScreen(edit: true),
    ),
  ),
  GoRoute(
    path: '/broker',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const BrokerIntroScreen()),
  ),
  GoRoute(
    path: '/broker/list',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const BrokerListScreen()),
  ),
  GoRoute(
    path: '/broker/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: BrokerProfileScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/sell',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const EBrokerIntroScreen()),
  ),
  GoRoute(
    path: '/sell/:id',
    // `new` is the form, which lives outside the shell (it has its own action bar); the shell
    // route would otherwise read it as the id of a submission.
    redirect: (context, state) =>
        state.pathParameters['id'] == 'new' ? '/sell-new' : null,
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: EBrokerDetailScreen(
        id: state.pathParameters['id']!,
        flash: state.uri.queryParameters['flash'],
      ),
    ),
  ),
];
