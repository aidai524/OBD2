import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:obd2app/app/app_routes.dart';
import 'package:obd2app/app/app_shell.dart';
import 'package:obd2app/core/errors/recoverable_error_view.dart';
import 'package:obd2app/core/i18n/app_localizations.dart';

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
      final localizations = AppLocalizations.of(context);
      return RecoverableErrorView(
        icon: AppErrorIcon.notFound,
        title: localizations.pageNotFoundTitle,
        message: localizations.pageUnavailableMessage,
        actionLabel: localizations.backToGarageAction,
        onAction: () => context.go(AppRoutes.garage),
      );
    },
  );

  ref.onDispose(router.dispose);
  return router;
});
