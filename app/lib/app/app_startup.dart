import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obd2app/app/app.dart';
import 'package:obd2app/core/config/app_config.dart';
import 'package:obd2app/core/config/app_config_provider.dart';
import 'package:obd2app/core/errors/recoverable_error_view.dart';
import 'package:obd2app/core/i18n/app_locale.dart';
import 'package:obd2app/core/i18n/app_localizations.dart';
import 'package:obd2app/core/theme/app_theme.dart';
import 'package:obd2app/core/theme/app_tokens.dart';

typedef AppConfigLoader = FutureOr<AppConfig> Function();

class AppStartup extends StatefulWidget {
  const AppStartup({this.loadConfig = AppConfig.fromCompileTime, super.key});

  final AppConfigLoader loadConfig;

  @override
  State<AppStartup> createState() => _AppStartupState();
}

class _AppStartupState extends State<AppStartup> {
  AppConfig? _config;
  var _isLoading = true;
  var _isInitializing = true;
  var _loadToken = 0;

  @override
  void initState() {
    super.initState();
    _loadConfig(showLoading: false);
    _isInitializing = false;
  }

  @override
  void didUpdateWidget(AppStartup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadConfig != widget.loadConfig) {
      _loadConfig();
    }
  }

  void _loadConfig({bool showLoading = true}) {
    final token = ++_loadToken;
    if (showLoading) {
      _updateState(() {
        _config = null;
        _isLoading = true;
      });
    }

    final FutureOr<AppConfig> result;
    try {
      result = widget.loadConfig();
    } on Object {
      _finishWithError(token);
      return;
    }

    if (result is Future<AppConfig>) {
      unawaited(_awaitConfig(result, token));
    } else {
      _finishWithConfig(result, token);
    }
  }

  Future<void> _awaitConfig(Future<AppConfig> future, int token) async {
    try {
      _finishWithConfig(await future, token);
    } on Object {
      _finishWithError(token);
    }
  }

  void _finishWithConfig(AppConfig config, int token) {
    if (!mounted || token != _loadToken) {
      return;
    }
    _updateState(() {
      _config = config;
      _isLoading = false;
    });
  }

  void _finishWithError(int token) {
    if (!mounted || token != _loadToken) {
      return;
    }
    _updateState(() {
      _config = null;
      _isLoading = false;
    });
  }

  void _updateState(VoidCallback update) {
    if (_isInitializing) {
      update();
    } else {
      setState(update);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    if (config != null) {
      return ProviderScope(
        overrides: [appConfigProvider.overrideWithValue(config)],
        child: const MainApp(),
      );
    }

    if (_isLoading) {
      return const _StartupMaterialApp(home: _StartupLoadingView());
    }

    return _StartupMaterialApp(home: _StartupErrorView(onRetry: _loadConfig));
  }
}

class _StartupLoadingView extends StatelessWidget {
  const _StartupLoadingView();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppSpacing.medium),
              Text(localizations.startingMessage),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartupErrorView extends StatelessWidget {
  const _StartupErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return RecoverableErrorView(
      icon: AppErrorIcon.startup,
      title: localizations.startupErrorTitle,
      message: localizations.startupErrorMessage,
      actionLabel: localizations.tryAgainAction,
      onAction: onRetry,
    );
  }
}

class _StartupMaterialApp extends StatelessWidget {
  const _StartupMaterialApp({required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      locale: AppLocale.enUs,
      supportedLocales: const [AppLocale.enUs],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: home,
    );
  }
}
