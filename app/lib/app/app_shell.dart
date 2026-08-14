import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obd2app/app/app_routes.dart';
import 'package:obd2app/core/i18n/app_localizations.dart';

enum AppTab {
  garage(
    location: AppRoutes.garage,
    icon: Icons.garage_outlined,
    selectedIcon: Icons.garage,
  ),
  diagnostics(
    location: AppRoutes.diagnostics,
    icon: Icons.troubleshoot_outlined,
    selectedIcon: Icons.troubleshoot,
  ),
  liveData(
    location: AppRoutes.liveData,
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
  ),
  history(
    location: AppRoutes.history,
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  ),
  settings(
    location: AppRoutes.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const AppTab({
    required this.location,
    required this.icon,
    required this.selectedIcon,
  });

  final String location;
  final IconData icon;
  final IconData selectedIcon;

  String label(AppLocalizations localizations) {
    return switch (this) {
      AppTab.garage => localizations.garageTab,
      AppTab.diagnostics => localizations.diagnosticsTab,
      AppTab.liveData => localizations.liveDataTab,
      AppTab.history => localizations.historyTab,
      AppTab.settings => localizations.settingsTab,
    };
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label(localizations),
            ),
        ],
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}

class AppTabPage extends StatelessWidget {
  const AppTabPage({required this.tab, super.key});

  final AppTab tab;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final label = tab.label(localizations);
    return Scaffold(
      key: ValueKey('tab-page-${tab.name}'),
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text(localizations.tabPlaceholder(label))),
    );
  }
}
