import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/app/app_startup.dart';
import 'package:obd2app/core/config/app_config.dart';
import 'package:obd2app/core/i18n/app_locale.dart';
import 'package:obd2app/core/i18n/app_localizations.dart';

void main() {
  test('uses the profile and intl names for en-US', () {
    expect(AppLocale.enUs, const Locale('en', 'US'));
    expect(AppLocale.profileTag, 'en-US');
    expect(AppLocale.intlName, 'en_US');
  });

  testWidgets('locks the running application to en-US and dark mode', (
    tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale('zh', 'CN');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);

    await tester.pumpWidget(AppStartup(loadConfig: () => _testConfig));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final pageContext = tester.element(
      find.byKey(const ValueKey('tab-page-garage')),
    );

    expect(materialApp.locale, AppLocale.enUs);
    expect(materialApp.supportedLocales, const [AppLocale.enUs]);
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(Localizations.localeOf(pageContext), AppLocale.enUs);
    expect(AppLocalizations.of(pageContext).localeName, 'en_US');
    expect(find.text('Garage'), findsWidgets);
    expect(find.text('Diagnostics'), findsOneWidget);
    expect(find.text('Live Data'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('uses the same en-US dark theme for startup failures', (
    tester,
  ) async {
    await tester.pumpWidget(
      AppStartup(loadConfig: () => throw StateError('private detail')),
    );
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final errorContext = tester.element(find.text('Unable to start'));

    expect(materialApp.locale, AppLocale.enUs);
    expect(materialApp.supportedLocales, const [AppLocale.enUs]);
    expect(materialApp.themeMode, ThemeMode.dark);
    expect(Theme.of(errorContext).brightness, Brightness.dark);
    expect(find.textContaining('private detail'), findsNothing);
  });
}

final _testConfig = AppConfig.fromValues(
  appEnvironment: 'dev',
  supabaseUrl: 'http://127.0.0.1:54321',
  supabasePublishableKey: 'public-test-key',
);
