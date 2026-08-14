import 'package:flutter/material.dart';

@immutable
final class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({required this.instrumentValue});

  static const dark = AppTypography(
    instrumentValue: TextStyle(
      fontWeight: FontWeight.w600,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  );

  final TextStyle instrumentValue;

  @override
  AppTypography copyWith({TextStyle? instrumentValue}) {
    return AppTypography(
      instrumentValue: instrumentValue ?? this.instrumentValue,
    );
  }

  @override
  AppTypography lerp(covariant ThemeExtension<AppTypography>? other, double t) {
    if (other is! AppTypography) {
      return this;
    }
    return AppTypography(
      instrumentValue: TextStyle.lerp(
        instrumentValue,
        other.instrumentValue,
        t,
      )!,
    );
  }
}
