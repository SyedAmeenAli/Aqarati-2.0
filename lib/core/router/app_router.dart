import 'package:flutter/widgets.dart' show ValueKey;
import 'package:go_router/go_router.dart';

import '../../features/business/aq_business_profile.dart';
import '../../features/business/aq_business_projects.dart' show AQProjectDetailScreen;
import '../../features/contact/contact_actions.dart' show AQChatsScreen;
import '../../features/business/aq_professionals.dart';
import '../../features/property/property_detail_screen.dart';
import '../../features/account/delete_account_screen.dart';
import '../../features/activity/activity_screen.dart';
import '../../features/compare/compare_screen.dart';
import '../../features/maintenance/maintenance_screens.dart';
import '../../features/notifications/notifications.dart';
import 'extra_routes.dart';
import '../../features/saved/saved_screen.dart';
import '../../features/search/aq_map.dart';
import '../../features/search/aq_property_types.dart';
import '../../features/search/aq_properties_hub.dart';
import '../../features/settings/business_settings_screen.dart' show ProBusinessSettingsScreen;
import '../../features/settings/settings_screens.dart' show kSettingsRoutes, kProSettings, settingsPageFor;
import '../../features/analytics/analytics_screens.dart' show ProAnalyticsScreen;
import '../../features/entry/screens/onboarding_entry_screen.dart';
import '../../features/entry/models/signup_purpose.dart';
import '../../features/flow/screens/auth_screens.dart';
import '../../features/flow/screens/email_verification_screen.dart';
import '../../features/flow/screens/legal_screens.dart';
import '../../features/flow/screens/otp_screens.dart';
import '../../features/flow/screens/signup_form_screen.dart';
import '../../features/flow/screens/approval_screens.dart';
import '../../features/flow/screens/verification_onboarding_screens.dart';
import '../../features/flow/screens/verification_status_screens.dart';
import '../../features/entry/screens/purpose_selection_screen.dart';
import '../../features/onboarding/interests.dart';
import '../../features/entry/widgets/entry_common.dart';
import '../../features/viewing/screens/viewing_detail_screen.dart';
import '../../features/viewing/screens/viewing_schedule_screens.dart';
import '../../features/viewing/screens/viewing_status_screens.dart';
import '../../features/workspace/aq_home.dart' show AQPropertiesScreen;
import '../../features/calculators/calculator_models.dart';
import '../../features/calculators/calculator_screen.dart';
import '../../features/calculators/calculators_list_screen.dart';
import '../aq/aq_scene.dart' show AQRoute;
import '../../features/listings/listing_screens.dart';
import '../../features/leads/lead_models.dart';
import '../../features/leads/lead_screens.dart';
import '../../features/workspace/aq_app_shell.dart';
import '../../features/devbuild/db_routes.dart';
import '../../admin/admin_host.dart';
import '../../features/agent/agent_routes.dart';
import '../../features/pro/pro_shell.dart';
import '../../features/pro/pro_tab_screens.dart';
import '../../features/agent/agent_shell.dart';
import '../../features/role_home/mode_switch.dart' show ShopGate, WorkGate;

final appRouter = GoRouter(
  initialLocation: '/entry',
  routes: [
    // The Admin Web Console: its own sign-in, navigation and routes, hosted at `#/admin`.
    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) =>
          AQRoute.fade(key: state.pageKey, child: const AdminConsoleHost()),
    ),
    // Shop and Work open the customer app or the workspace by what the signed-in account is, never the welcome screen.
    GoRoute(path: '/shop', pageBuilder: (context, state) => AQRoute.fade(key: state.pageKey, child: const ShopGate())),
    GoRoute(path: '/work', pageBuilder: (context, state) => AQRoute.fade(key: state.pageKey, child: const WorkGate())),
    GoRoute(
      path: '/entry',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const OnboardingEntryScreen()),
    ),
    GoRoute(
      path: '/onboarding/purpose',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const PurposeSelectionScreen()),
    ),
    GoRoute(
      path: '/signup/business',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: const PurposeSelectionScreen(businessOnly: true),
      ),
    ),
    GoRoute(
      path: '/onboarding/interests',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const InterestsScreen()),
    ),
    GoRoute(
      path: '/legal/terms',
      pageBuilder: (context, state) => AQRoute.sheet(
        key: state.pageKey,
        child: const LegalScreen(kind: LegalKind.terms),
      ),
    ),
    GoRoute(
      path: '/legal/privacy',
      pageBuilder: (context, state) => AQRoute.sheet(
        key: state.pageKey,
        child: const LegalScreen(kind: LegalKind.privacy),
      ),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: LoginScreen(experience: state.uri.queryParameters['as'], next: state.uri.queryParameters['next'])),
    ),
    GoRoute(
      path: '/forgot-password',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const ForgotPasswordScreen()),
    ),
    GoRoute(
      path: '/reset-password',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: ResetPasswordScreen(
          key: ValueKey(state.uri.queryParameters['oobCode']),
          oobCode: state.uri.queryParameters['oobCode'],
        ),
      ),
    ),
    for (final o in signupPurposeOptions)
      GoRoute(
        path: o.route,
        pageBuilder: (context, state) => brandPage(
          key: state.pageKey,
          child: SignupFormScreen(purpose: o.id),
        ),
      ),
    GoRoute(
      path: '/otp',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const OtpScreen()),
    ),
    GoRoute(
      path: '/verify-email',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const EmailVerificationScreen()),
    ),
    GoRoute(
      path: '/account/active',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const AccountActiveScreen()),
    ),
    GoRoute(
      path: '/onboarding/documents',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: const DocumentOnboardingScreen(),
      ),
    ),
    GoRoute(
      path: '/onboarding/verification-intro',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const VerificationIntroScreen()),
    ),
    GoRoute(
      path: '/onboarding/review',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const ApplicationReviewScreen()),
    ),
    GoRoute(
      path: '/onboarding/submitted',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: const ApplicationSubmittedScreen(),
      ),
    ),
    GoRoute(
      path: '/verification',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: const VerificationStatusScreen(),
      ),
    ),
    GoRoute(
      path: '/verification/details',
      pageBuilder: (context, state) => brandPage(
        key: state.pageKey,
        child: const ApplicationDetailsScreen(),
      ),
    ),
    GoRoute(
      path: '/verification/resubmit',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const ResubmissionScreen()),
    ),
    GoRoute(
      path: '/verification/resubmit/review',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const ResubmitReviewScreen()),
    ),
    GoRoute(
      path: '/verification/resubmitted',
      pageBuilder: (context, state) =>
          brandPage(key: state.pageKey, child: const ResubmittedScreen()),
    ),
    GoRoute(
      path: '/verification/approved',
      pageBuilder: (context, state) =>
          AQRoute.hero(key: state.pageKey, child: const ApprovedScreen()),
    ),
    GoRoute(
      path: '/verification/summary',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: const VerifiedSummaryScreen(),
      ),
    ),
    GoRoute(
      path: '/workspace/activation',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: const WorkspaceActivationScreen(),
      ),
    ),
    // A property page is full screen: its own pinned Enquire / Book viewing bar is the only bottom
    // element, so nothing stacks over the gallery or the end of the page.
    GoRoute(
      path: '/property/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: PropertyDetailScreen(propertyId: state.pathParameters['id']!),
      ),
    ),
    ShellRoute(
      builder: (context, state, child) => AQAppShell(child: child),
      routes: [
        GoRoute(
          path: '/app/home',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const HomeTab()),
        ),
        GoRoute(
          path: '/app/explore',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ExploreTab()),
        ),
        GoRoute(
          path: '/app/activity',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ActivityScreen()),
        ),
        GoRoute(
          path: '/app/account',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const AccountTab()),
        ),
        // Customer browsing screens live inside the shell so the bottom navigation stays put.
    GoRoute(
      path: '/properties',
      // Plain `/properties` is the Properties landing page (Buy, Rent, Sell, My Favorites); with a
      // category, transaction or type it is the results list.
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: (state.uri.queryParameters['cat'] == null &&
                state.uri.queryParameters['tx'] == null &&
                state.uri.queryParameters['types'] == null)
            ? const AQPropertiesHubScreen()
            : AQPropertiesScreen(
          category: state.uri.queryParameters['cat'],
          tx: state.uri.queryParameters['tx'],
          types: state.uri.queryParameters['types'],
        ),
      ),
    ),
    GoRoute(
      path: '/properties/categories',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQCategoryStepScreen(tx: state.uri.queryParameters['tx']),
      ),
    ),
    GoRoute(
      path: '/properties/types',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQTypeStepScreen(
          tx: state.uri.queryParameters['tx'],
          cat: state.uri.queryParameters['cat'],
        ),
      ),
    ),
    GoRoute(
      path: '/properties/all',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQPropertiesScreen(
          category: state.uri.queryParameters['cat'],
          tx: state.uri.queryParameters['tx'],
          types: state.uri.queryParameters['types'],
        ),
      ),
    ),
    GoRoute(
      path: '/saved',
      pageBuilder: (context, state) =>
          AQRoute.forward(key: state.pageKey, child: const SavedScreen()),
    ),
    GoRoute(
      path: '/professionals',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQProfessionalsScreen(
          key: ValueKey(state.uri.toString()),
          query: state.uri.queryParameters['q'],
          category: state.uri.queryParameters['cat'],
        ),
      ),
    ),
    GoRoute(
      path: '/business/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQBusinessProfileScreen(businessId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/business/:id/project/:pid',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQProjectDetailScreen(businessId: state.pathParameters['id']!, projectId: state.pathParameters['pid']!),
      ),
    ),
    GoRoute(
      path: '/chats',
      pageBuilder: (context, state) => AQRoute.forward(key: state.pageKey, child: const AQChatsScreen()),
    ),
    GoRoute(
      path: '/calculators',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const CalculatorsListScreen(),
      ),
    ),
    GoRoute(
      path: '/calculators/:id',
      pageBuilder: (context, state) {
        final type = CalculatorType.values
            .where((t) => t.name == state.pathParameters['id'])
            .firstOrNull;
        return AQRoute.forward(
          key: state.pageKey,
          child: type == null
              ? const CalculatorsListScreen()
              : CalculatorScreen(type: type),
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const NotificationsScreen(),
      ),
    ),
    GoRoute(
      path: '/map',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: AQMapScreen(tx: state.uri.queryParameters['tx']),
      ),
    ),
    // One search page: the old search routes lead to Explore, which is the unified search.
    GoRoute(
      path: '/search',
      redirect: (context, state) {
        final q = state.uri.queryParameters['q'];
        return q == null || q.isEmpty ? '/app/explore' : '/app/explore?q=${Uri.encodeQueryComponent(q)}';
      },
    ),
    GoRoute(path: '/search/start', redirect: (context, state) => '/app/explore?focus=1'),
        ...extraShellRoutes(),
        ...dbShellRoutes(),
      ],
    ),
    // The business workspaces (Development, Construction, Architecture, Interior & Exterior).
    ShellRoute(
      builder: (context, state, child) => ProShell(child: child),
      routes: [
        GoRoute(
          path: '/pro',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProHomeScreen()),
        ),
        GoRoute(
          path: '/pro/settings',
          pageBuilder: (context, state) =>
              AQRoute.forward(key: state.pageKey, child: const ProBusinessSettingsScreen()),
        ),
        for (final name in kSettingsRoutes)
          GoRoute(
            path: '/pro/settings/p/$name',
            pageBuilder: (context, state) => AQRoute.forward(
              key: state.pageKey,
              child: settingsPageFor(name, kProSettings),
            ),
          ),
        GoRoute(
          path: '/pro/analytics',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProAnalyticsScreen()),
        ),
        GoRoute(
          path: '/pro/units',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProUnitsScreen()),
        ),
        GoRoute(
          path: '/pro/projects',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProProjectsScreen()),
        ),
        GoRoute(
          path: '/pro/services',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProServicesScreen()),
        ),
        GoRoute(
          path: '/pro/more',
          pageBuilder: (context, state) =>
              AQRoute.tab(key: state.pageKey, child: const ProMoreScreen()),
        ),
        ...dbProShellRoutes(),
      ],
    ),
    // The Real Estate Agent workspace: its own navigation, never the customer's.
    ShellRoute(
      builder: (context, state, child) => AgentShell(child: child),
      routes: [
        ...agentShellRoutes(),
    GoRoute(
      path: '/agent/listings',
      pageBuilder: (context, state) =>
          AQRoute.forward(key: state.pageKey, child: const MyListingsScreen()),
    ),
    GoRoute(
      path: '/agent/listings/new',
      pageBuilder: (context, state) =>
          AQRoute.forward(key: state.pageKey, child: const ListingFormScreen()),
    ),
    GoRoute(
      path: '/agent/listings/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ListingDetailScreen(
          id: state.pathParameters['id']!,
          flash: state.uri.queryParameters['flash'],
        ),
      ),
    ),
    GoRoute(
      path: '/agent/listings/:id/edit',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ListingFormScreen(editId: state.pathParameters['id']),
      ),
    ),
    GoRoute(
      path: '/agent/leads',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const LeadInboxScreen(scope: LeadScope.agent),
      ),
    ),
    GoRoute(
      path: '/agent/leads/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: LeadDetailScreen(
          scope: LeadScope.agent,
          id: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: '/workspace/enquiries',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const LeadInboxScreen(scope: LeadScope.developer),
      ),
    ),
    GoRoute(
      path: '/workspace/enquiries/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: LeadDetailScreen(
          scope: LeadScope.developer,
          id: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: '/workspace/requests',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const LeadInboxScreen(scope: LeadScope.service),
      ),
    ),
    GoRoute(
      path: '/workspace/requests/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: LeadDetailScreen(
          scope: LeadScope.service,
          id: state.pathParameters['id']!,
        ),
      ),
    ),
      ],
    ),
    // Property viewing journey (screens 39-51). Back reverses the logical journey.
    GoRoute(
      path: '/property/:id/viewing',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ViewingAvailabilityScreen(
          propertyId: state.pathParameters['id']!,
        ),
      ),
    ),
    GoRoute(
      path: '/property/:id/viewing/slot',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ViewingSlotScreen(propertyId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/property/:id/viewing/review',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ViewingReviewScreen(propertyId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/property/:id/viewing/conflict',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingConflictScreen(propertyId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(path: '/viewings', redirect: (context, state) => '/app/activity'),
    GoRoute(
      path: '/viewings/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: ViewingDetailScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/requested',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingRequestedScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/confirmed',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingConfirmedScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/declined',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingDeclinedScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/reschedule',
      pageBuilder: (context, state) => AQRoute.sheet(
        key: state.pageKey,
        child: ViewingRescheduleScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/cancel',
      pageBuilder: (context, state) => AQRoute.sheet(
        key: state.pageKey,
        child: ViewingCancelScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/cancelled',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingCancelledScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/completed',
      pageBuilder: (context, state) => AQRoute.hero(
        key: state.pageKey,
        child: ViewingCompletedScreen(id: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/viewings/:id/review',
      pageBuilder: (context, state) => AQRoute.sheet(
        key: state.pageKey,
        child: ViewingReviewEntryScreen(
          id: state.pathParameters['id']!,
          rating: int.tryParse(state.uri.queryParameters['rating'] ?? ''),
        ),
      ),
    ),
    ...dbStandaloneRoutes(),
    GoRoute(
      path: '/business/:id/book',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: MaintenanceBookScreen(providerId: state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/bookings/:id',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: MaintenanceDetailScreen(id: state.pathParameters['id']!),
      ),
    ),
    ...extraRoutes(),
    GoRoute(
      path: '/account/delete',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: const DeleteAccountScreen(),
      ),
    ),
    GoRoute(
      path: '/compare',
      pageBuilder: (context, state) => AQRoute.forward(
        key: state.pageKey,
        child: CompareScreen(
          propertyIds: (state.uri.queryParameters['ids'] ?? '')
              .split(',')
              .where((x) => x.isNotEmpty)
              .toList(),
        ),
      ),
    ),
  ],
);
