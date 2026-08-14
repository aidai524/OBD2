import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/app/app_startup.dart';
import 'package:obd2app/core/config/app_config.dart';
import 'package:obd2app/main.dart' as app;

void main() {
  testWidgets('shows a safe loading state before startup completes', (
    tester,
  ) async {
    final completer = Completer<AppConfig>();

    await tester.pumpWidget(AppStartup(loadConfig: () => completer.future));
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Starting…'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);

    completer.complete(_testConfig);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
  });

  testWidgets('retries a failed startup and then enters the app', (
    tester,
  ) async {
    final retryCompleter = Completer<AppConfig>();
    var attempts = 0;

    await tester.pumpWidget(
      AppStartup(
        loadConfig: () {
          attempts++;
          if (attempts == 1) {
            throw StateError('private startup detail');
          }
          return retryCompleter.future;
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.text('Unable to start'), findsOneWidget);
    expect(
      find.text('The app could not finish starting safely.'),
      findsOneWidget,
    );
    expect(find.textContaining('private startup detail'), findsNothing);

    await tester.tap(find.text('Try Again'));
    await tester.pump();

    expect(attempts, 2);
    expect(find.text('Starting…'), findsOneWidget);

    retryCompleter.complete(_testConfig);
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byKey(const ValueKey('tab-page-garage')), findsOneWidget);
  });

  testWidgets('remains recoverable after repeated startup failures', (
    tester,
  ) async {
    var attempts = 0;

    await tester.pumpWidget(
      AppStartup(
        loadConfig: () {
          attempts++;
          return Future<AppConfig>.error(
            StateError('never render this detail'),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Try Again'));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('Unable to start'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.textContaining('never render this detail'), findsNothing);
  });

  const compileTimeEnvironment = String.fromEnvironment('APP_ENV');
  if (compileTimeEnvironment.isNotEmpty) {
    testWidgets('starts from the selected compile-time profile', (
      tester,
    ) async {
      app.main();
      await tester.pump();
      await tester.pump();

      expect(
        find.byKey(ValueKey('app-$compileTimeEnvironment')),
        findsOneWidget,
      );
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  }
}

final _testConfig = AppConfig.fromValues(
  appEnvironment: 'dev',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'public-test-key',
);
