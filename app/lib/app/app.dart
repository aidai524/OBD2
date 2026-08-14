import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obd2app/app/app_router.dart';
import 'package:obd2app/core/config/app_config_provider.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      key: ValueKey('app-${config.environment.name}'),
      title: 'OBD2 App',
      routerConfig: router,
    );
  }
}
