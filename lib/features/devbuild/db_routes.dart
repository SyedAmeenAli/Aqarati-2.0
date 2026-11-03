import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/aq/aq_scene.dart' show AQRoute;
import '../../core/domain/account_models.dart' show InteriorExteriorServiceType;
import 'db_discovery.dart';
import 'db_models.dart';
import 'db_pro_tools.dart';
import 'db_profile.dart';
import 'db_projects.dart';
import 'db_wizard.dart';
import 'db_workspace.dart';
import 'db_repository.dart';

/// Routes inside the customer shell: the four-tab nav stays visible and Explore stays selected.
List<RouteBase> dbShellRoutes() => [
  GoRoute(
    path: '/app/explore/build',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbHomeScreen()),
  ),
  GoRoute(
    path: '/app/explore/build/categories',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbCategoriesScreen()),
  ),
  GoRoute(
    path: '/app/explore/build/results',
    pageBuilder: (context, state) {
      final q = state.uri.queryParameters;
      return AQRoute.forward(
        key: ValueKey(state.uri.toString()),
        child: DbResultsScreen(
          initial: DbQuery(
            type: proTypeOfName(q['cat']),
            text: q['q'] ?? '',
            governorate: omanGovernorates.containsKey(q['gov'])
                ? q['gov']
                : null,
            serviceType: InteriorExteriorServiceType.values
                .where((s) => s.name == q['svc'])
                .firstOrNull,
          ),
          map: q['view'] == 'map',
        ),
      );
    },
  ),
];

/// Full-screen routes (no tab nav): profiles, project pages, gallery.
List<RouteBase> dbStandaloneRoutes() => [
  GoRoute(
    path: '/build/pro/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbProfileScreen(id: state.pathParameters['id']!, service: state.uri.queryParameters['svc']),
    ),
  ),
  GoRoute(
    path: '/build/pro/:id/reviews',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbReviewsScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/build/pro/:id/projects',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbProjectsScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/build/project/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbProjectDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/build/project/:id/gallery',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbGalleryScreen(
        id: state.pathParameters['id']!,
        initial: int.tryParse(state.uri.queryParameters['i'] ?? '') ?? 0,
      ),
    ),
  ),
  GoRoute(
    path: '/app/account/workspace/profile/status',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: const DbProfileStatusScreen(),
    ),
  ),
  GoRoute(
    path: '/workspace/projects/new',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbWizardScreen()),
  ),
  GoRoute(
    path: '/workspace/projects/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbProjectStatusScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/workspace/projects/:id/edit',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbWizardScreen(
        projectId: state.pathParameters['id'],
        startStep: int.tryParse(state.uri.queryParameters['step'] ?? '') ?? 0,
      ),
    ),
  ),
  GoRoute(
    path: '/workspace/projects/:id/submitted',
    pageBuilder: (context, state) => AQRoute.hero(
      key: state.pageKey,
      child: DbSubmittedScreen(
        id: state.pathParameters['id']!,
        result: state.uri.queryParameters['r'] ?? 'submitted',
      ),
    ),
  ),
];

/// The business workspace pages, hosted by the professional shell (`ProShell`), never the customer's.
List<RouteBase> dbProShellRoutes() => [
  GoRoute(
    path: '/app/account/workspace',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbDashboardScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/projects',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbMyProjectsScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/profile',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbProfileEditScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/leads',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbLeadsScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/reviews',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbBizReviewsScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/engagements',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbEngagementsScreen()),
  ),
  GoRoute(
    path: '/app/account/workspace/portfolio',
    pageBuilder: (context, state) =>
        AQRoute.forward(key: state.pageKey, child: const DbPortfolioScreen()),
  ),
  GoRoute(
    path: '/workspace/leads/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbLeadDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
  GoRoute(
    path: '/workspace/engagements/:id',
    pageBuilder: (context, state) => AQRoute.forward(
      key: state.pageKey,
      child: DbEngagementDetailScreen(id: state.pathParameters['id']!),
    ),
  ),
];
