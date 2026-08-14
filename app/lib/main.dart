import 'package:flutter/material.dart';
import 'package:obd2app/core/config/app_config.dart';

void main() {
  final config = AppConfig.fromCompileTime();
  runApp(MainApp(config: config));
}

class MainApp extends StatelessWidget {
  const MainApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(config.environment),
      title: 'OBD2 App',
      home: const Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
