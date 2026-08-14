import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:obd2app/core/config/app_config.dart';

final appConfigProvider = Provider<AppConfig>((ref) {
  throw StateError('appConfigProvider must be overridden at startup.');
});
