import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:obd2app/app/app.dart';
import 'package:obd2app/app/app_router.dart';
import 'package:obd2app/app/app_routes.dart';
import 'package:obd2app/app/app_shell.dart';
import 'package:obd2app/core/config/app_config.dart';
import 'package:obd2app/core/config/app_config_provider.dart';

void main() {
  testWidgets('shows the five tabs in the required order', (tester) async {
    final router = await _pumpApp(tester);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    final labels = navigationBar.destinations.cast<NavigationDestination>().map(
      (destination) => destination.label,
    );

    expect(
      labels,
      orderedEquals([
        'Garage',
        'Diagnostics',
        'Live Data',
        'History',
        'Settings',
      ]),
    );
    expect(navigationBar.selectedIndex, 0);
    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.garage);
    expect(find.byKey(const ValueKey('app-dev')), findsOneWidget);
  });

  testWidgets('keeps all tab labels accessible on a compact large-text view', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 568);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();

    await _pumpApp(tester);

    for (final tab in AppTab.values) {
      final label = find.descendant(
        of: find.byType(NavigationDestination).at(tab.index),
        matching: find.text(tab.label),
      );
      expect(label, findsOneWidget);
      expect(
        tester.getSemantics(label),
        isSemantics(
          label: '${tab.label}\nTab ${tab.index + 1} of 5',
          isButton: true,
          hasTapAction: true,
        ),
      );
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('switches between all five tab branches', (tester) async {
    final router = await _pumpApp(tester);

    for (var index = 1; index < AppTab.values.length; index++) {
      final tab = AppTab.values[index];
      await tester.tap(find.byType(NavigationDestination).at(index));
      await tester.pumpAndSettle();

      expect(find.byKey(ValueKey('tab-page-${tab.name}')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        index,
      );
      expect(router.routeInformationProvider.value.uri.path, tab.location);
    }

    await tester.tap(find.byType(NavigationDestination).first);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.garage);
  });

  for (final tab in AppTab.values) {
    testWidgets('opens ${tab.label} from ${tab.location}', (tester) async {
      await _pumpApp(tester, initialLocation: tab.location);

      expect(find.byKey(ValueKey('tab-page-${tab.name}')), findsOneWidget);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        tab.index,
      );
    });
  }

  testWidgets('redirects the root route to Garage', (tester) async {
    final router = await _pumpApp(tester, initialLocation: AppRoutes.root);

    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.garage);
  });

  testWidgets('recovers safely from an unknown route', (tester) async {
    final router = await _pumpApp(tester);
    final semantics = tester.ensureSemantics();

    router.go('/missing?token=do-not-render');
    await tester.pumpAndSettle();

    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('This page is unavailable.'), findsOneWidget);
    expect(find.textContaining('do-not-render'), findsNothing);
    expect(find.textContaining('GoException'), findsNothing);
    expect(
      tester.getSemantics(find.text('Page not found')),
      isSemantics(label: 'Page not found', isHeader: true),
    );

    await tester.tap(find.text('Back to Garage'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, AppRoutes.garage);
    semantics.dispose();
  });
}

Future<GoRouter> _pumpApp(
  WidgetTester tester, {
  String initialLocation = AppRoutes.garage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appConfigProvider.overrideWithValue(_testConfig),
        appInitialLocationProvider.overrideWithValue(initialLocation),
      ],
      child: const MainApp(),
    ),
  );
  await tester.pumpAndSettle();

  final context = tester.element(find.byType(MainApp));
  return ProviderScope.containerOf(
    context,
    listen: false,
  ).read(appRouterProvider);
}

final _testConfig = AppConfig.fromValues(
  appEnvironment: 'dev',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'public-test-key',
);
