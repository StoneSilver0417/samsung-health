import 'package:flutter/material.dart';
import 'app_design_tokens.dart';

/// App ThemeData builder configured with AppDesignTokens
ThemeData buildAppTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.neon,
      onPrimary: Colors.black,
      surface: AppColors.bg,
      onSurface: AppColors.textPrimary,
      secondary: AppColors.neon,
      error: AppColors.danger,
    ),
    extensions: const [
      AppDesignTokens(),
    ],
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: AppSpacing.cardMargin,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br16,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      titleTextStyle: AppTypography.titleLarge,
      iconTheme: IconThemeData(
        color: AppColors.textPrimary,
        size: AppIconSizes.lg,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.neon.withValues(alpha: 0.18),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.cardElevated,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br12,
        side: BorderSide(color: AppColors.borderSubtle),
      ),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.br20,
      ),
      titleTextStyle: AppTypography.titleLarge,
      contentTextStyle: AppTypography.bodySmall,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheetTop,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.neon,
        foregroundColor: Colors.black,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br12,
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.borderSubtle),
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br12,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.brFull,
      ),
      side: const BorderSide(color: AppColors.borderSubtle),
    ),
  );
}
