import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:obd2app/app/app_routes.dart';

enum AppTab {
  garage(
    label: 'Garage',
    location: AppRoutes.garage,
    icon: Icons.garage_outlined,
    selectedIcon: Icons.garage,
  ),
  diagnostics(
    label: 'Diagnostics',
    location: AppRoutes.diagnostics,
    icon: Icons.troubleshoot_outlined,
    selectedIcon: Icons.troubleshoot,
  ),
  liveData(
    label: 'Live Data',
    location: AppRoutes.liveData,
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
  ),
  history(
    label: 'History',
    location: AppRoutes.history,
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
  ),
  settings(
    label: 'Settings',
    location: AppRoutes.settings,
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
  );

  const AppTab({
    required this.label,
    required this.location,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String location;
  final IconData icon;
  final IconData selectedIcon;
}

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: [
          for (final tab in AppTab.values)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
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
    return Scaffold(
      key: ValueKey('tab-page-${tab.name}'),
      appBar: AppBar(title: Text(tab.label)),
      body: Center(
        child: Text('${tab.label} content will be added in a later task.'),
      ),
    );
  }
}
