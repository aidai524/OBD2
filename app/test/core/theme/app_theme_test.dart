import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obd2app/core/theme/app_colors.dart';
import 'package:obd2app/core/theme/app_status_colors.dart';
import 'package:obd2app/core/theme/app_theme.dart';
import 'package:obd2app/core/theme/app_tokens.dart';
import 'package:obd2app/core/theme/app_typography.dart';

void main() {
  test('freezes the documented V1 design tokens', () {
    expect(AppColors.primary, const Color(0xFF0A84FF));
    expect(AppColors.danger, const Color(0xFFE53935));
    expect(AppColors.warning, const Color(0xFFFBC02D));
    expect(AppColors.normal, const Color(0xFF43A047));
    expect(AppRadii.card, 12);
  });

  test('builds a fixed Material 3 dark theme with accessible controls', () {
    final theme = AppTheme.dark;
    final platformDefaultTheme = ThemeData.dark(useMaterial3: true);

    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, AppColors.background);
    expect(theme.colorScheme.primary, AppColors.primary);
    expect(theme.colorScheme.onPrimary, AppColors.onPrimary);
    expect(theme.colorScheme.error, AppColors.danger);
    expect(theme.colorScheme.onError, AppColors.onStatus);
    expect(
      theme.textTheme.bodyMedium?.fontFamily,
      platformDefaultTheme.textTheme.bodyMedium?.fontFamily,
    );

    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(AppRadii.card));

    final buttonStyle = theme.filledButtonTheme.style!;
    final minimumSize = buttonStyle.minimumSize!.resolve({})!;
    expect(minimumSize.width, greaterThanOrEqualTo(48));
    expect(minimumSize.height, greaterThanOrEqualTo(48));
    expect(buttonStyle.backgroundColor!.resolve({}), AppColors.primary);
    expect(buttonStyle.foregroundColor!.resolve({}), AppColors.onPrimary);
  });

  test('exposes status and tabular-number theme extensions', () {
    final theme = AppTheme.dark;
    final status = theme.extension<AppStatusColors>()!;
    final typography = theme.extension<AppTypography>()!;

    expect(status.danger, AppColors.danger);
    expect(status.warning, AppColors.warning);
    expect(status.normal, AppColors.normal);
    expect(status.onStatus, AppColors.onStatus);
    expect(
      typography.instrumentValue.fontFeatures,
      contains(
        isA<FontFeature>()
            .having((feature) => feature.feature, 'feature', 'tnum')
            .having((feature) => feature.value, 'value', 1),
      ),
    );
  });

  test('keeps every text token pair at WCAG AA contrast', () {
    final pairs = <(Color, Color)>[
      (AppColors.onSurface, AppColors.background),
      (AppColors.onSurface, AppColors.surface),
      (AppColors.onSurfaceMuted, AppColors.background),
      (AppColors.onSurfaceMuted, AppColors.surface),
      (AppColors.onPrimary, AppColors.primary),
      (AppColors.onStatus, AppColors.danger),
      (AppColors.onStatus, AppColors.warning),
      (AppColors.onStatus, AppColors.normal),
    ];

    for (final (foreground, background) in pairs) {
      expect(
        _contrastRatio(foreground, background),
        greaterThanOrEqualTo(4.5),
        reason: '$foreground on $background must meet WCAG AA.',
      );
    }
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance > secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance > secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
