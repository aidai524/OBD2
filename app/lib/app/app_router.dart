import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:obd2app/app/app_routes.dart';
import 'package:obd2app/app/app_shell.dart';
import 'package:obd2app/core/errors/recoverable_error_view.dart';

final appInitialLocationProvider = Provider<String>((ref) => AppRoutes.garage);

final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: ref.watch(appInitialLocationProvider),
    routes: [
      GoRoute(
        path: AppRoutes.root,
        redirect: (context, state) => AppRoutes.garage,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          for (final tab in AppTab.values)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: tab.location,
                  builder: (context, state) => AppTabPage(tab: tab),
                ),
              ],
            ),
        ],
      ),
    ],
    errorBuilder: (context, state) {
      return RecoverableErrorView(
        icon: AppErrorIcon.notFound,
        title: 'Page not found',
        message: 'This page is unavailable.',
        actionLabel: 'Back to Garage',
        onAction: () => context.go(AppRoutes.garage),
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});
