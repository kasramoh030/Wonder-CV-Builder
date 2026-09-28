import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/app_settings.dart';
import '../../features/analyser/analyser_screen.dart';
import '../../features/builder/builder_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/importing/import_screen.dart';
import '../../features/jobs/job_match_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/preview/preview_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/templates/templates_screen.dart';
import '../theme/app_spacing.dart';

/// Route names, so navigation calls never depend on literal paths.
abstract final class AppRoutes {
  static const String onboarding = 'onboarding';
  static const String dashboard = 'dashboard';
  static const String templates = 'templates';
  static const String settings = 'settings';
  static const String builder = 'builder';
  static const String preview = 'preview';
  static const String analyser = 'analyser';
  static const String jobMatch = 'jobMatch';
  static const String import = 'import';

  static String builderPath(String resumeId) => '/cv/$resumeId/edit';
  static String previewPath(String resumeId) => '/cv/$resumeId/preview';
  static String analyserPath(String resumeId) => '/cv/$resumeId/analyse';
  static String jobMatchPath(String resumeId) => '/cv/$resumeId/job-match';
}

/// The application's single [GoRouter].
///
/// The router is created once and kept alive for the process; onboarding
/// state is read through [Ref.read] inside `redirect` and the router is told
/// to re-evaluate whenever settings change. That keeps the shell's
/// navigation stack (and any unsaved builder state) intact across settings
/// updates, which a rebuilt router would destroy.
final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((Ref ref) {
  final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  ref.listen<AsyncValue<AppSettings>>(settingsProvider, (
    AsyncValue<AppSettings>? previous,
    AsyncValue<AppSettings> next,
  ) {
    refreshSignal.value++;
  });

  final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/cv',
    refreshListenable: refreshSignal,
    redirect: (BuildContext context, GoRouterState state) {
      final AppSettings settings =
          ref.read(settingsProvider).valueOrNull ?? AppSettings.defaults;
      final bool onOnboarding = state.matchedLocation == '/onboarding';

      if (!settings.onboardingCompleted) {
        return onOnboarding ? null : '/onboarding';
      }
      if (onOnboarding) return '/cv';
      return null;
    },
    routes: <RouteBase>[
      GoRoute(
        path: '/onboarding',
        name: AppRoutes.onboarding,
        builder: (BuildContext context, GoRouterState state) =>
            const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (
          BuildContext context,
          GoRouterState state,
          StatefulNavigationShell navigationShell,
        ) =>
            AppShell(navigationShell: navigationShell),
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/cv',
                name: AppRoutes.dashboard,
                builder: (BuildContext context, GoRouterState state) =>
                    const DashboardScreen(),
                routes: <RouteBase>[
                  GoRoute(
                    path: ':resumeId/edit',
                    name: AppRoutes.builder,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        BuilderScreen(resumeId: state.pathParameters['resumeId']!),
                  ),
                  GoRoute(
                    path: ':resumeId/preview',
                    name: AppRoutes.preview,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        PreviewScreen(resumeId: state.pathParameters['resumeId']!),
                  ),
                  GoRoute(
                    path: ':resumeId/analyse',
                    name: AppRoutes.analyser,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        AnalyserScreen(resumeId: state.pathParameters['resumeId']!),
                  ),
                  GoRoute(
                    path: ':resumeId/job-match',
                    name: AppRoutes.jobMatch,
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (BuildContext context, GoRouterState state) =>
                        JobMatchScreen(resumeId: state.pathParameters['resumeId']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/templates',
                name: AppRoutes.templates,
                builder: (BuildContext context, GoRouterState state) =>
                    const TemplatesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/import',
                name: AppRoutes.import,
                builder: (BuildContext context, GoRouterState state) =>
                    const ImportScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: '/settings',
                name: AppRoutes.settings,
                builder: (BuildContext context, GoRouterState state) =>
                    const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (BuildContext context, GoRouterState state) => Scaffold(
      body: Center(
        child: Padding(
          padding: AppSpacing.screen,
          child: Text(
            'Route not found: ${state.uri}',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );

  ref.onDispose(() {
    refreshSignal.dispose();
    router.dispose();
  });

  return router;
});

/// Key for the navigator that sits above the shell, so full-screen editor
/// flows cover the bottom navigation bar.
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
