import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/core/config/app_config.dart';
import 'package:obd2app/main.dart' as app;

void main() {
  testWidgets('starts the scaffold application', (tester) async {
    final config = AppConfig.fromValues(
      appEnvironment: 'dev',
      supabaseUrl: 'http://127.0.0.1:54321',
      supabasePublishableKey: 'public-test-key',
    );

    await tester.pumpWidget(app.MainApp(config: config));

    expect(find.text('Hello World!'), findsOneWidget);
  });

  const compileTimeEnvironment = String.fromEnvironment('APP_ENV');
  if (compileTimeEnvironment.isNotEmpty) {
    testWidgets('starts from the selected compile-time profile', (
      tester,
    ) async {
      app.main();
      await tester.pump();

      expect(find.text('Hello World!'), findsOneWidget);
    });
  }
}
