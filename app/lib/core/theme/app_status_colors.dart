import 'package:flutter/material.dart';
import 'package:obd2app/core/theme/app_colors.dart';

@immutable
final class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.danger,
    required this.warning,
    required this.normal,
    required this.onStatus,
  });

  static const dark = AppStatusColors(
    danger: AppColors.danger,
    warning: AppColors.warning,
    normal: AppColors.normal,
    onStatus: AppColors.onStatus,
  );

  final Color danger;
  final Color warning;
  final Color normal;
  final Color onStatus;

  @override
  AppStatusColors copyWith({
    Color? danger,
    Color? warning,
    Color? normal,
    Color? onStatus,
  }) {
    return AppStatusColors(
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      normal: normal ?? this.normal,
      onStatus: onStatus ?? this.onStatus,
    );
  }

  @override
  AppStatusColors lerp(
    covariant ThemeExtension<AppStatusColors>? other,
    double t,
  ) {
    if (other is! AppStatusColors) {
      return this;
    }
    return AppStatusColors(
      danger: Color.lerp(danger, other.danger, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      normal: Color.lerp(normal, other.normal, t)!,
      onStatus: Color.lerp(onStatus, other.onStatus, t)!,
    );
  }
}
