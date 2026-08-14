import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obd2app/app/app_router.dart';
import 'package:obd2app/core/config/app_config_provider.dart';
import 'package:obd2app/core/i18n/app_locale.dart';
import 'package:obd2app/core/i18n/app_localizations.dart';
import 'package:obd2app/core/theme/app_theme.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      key: ValueKey('app-${config.environment.name}'),
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: AppLocale.enUs,
      supportedLocales: const [AppLocale.enUs],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      routerConfig: router,
    );
  }
}
