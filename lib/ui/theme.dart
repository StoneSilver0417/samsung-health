import 'package:flutter/material.dart';

/// 다크 기본 + 네온 포인트 (PRD 4.4 디자인 톤 — 야간 러너)
class AppColors {
  static const bg = Color(0xFF0E1116);
  static const card = Color(0xFF161B22);
  static const neon = Color(0xFFC8FF3D);
  static const neonDim = Color(0xFF8BB22A);
  static const textPrimary = Color(0xFFF0F3F6);
  static const textSecondary = Color(0xFF8B949E);
  static const danger = Color(0xFFFF5D5D);
  static const zoneColors = [
    Color(0xFF4A90D9), // Z1
    Color(0xFF4AD9A5), // Z2
    Color(0xFFC8FF3D), // Z3
    Color(0xFFFFB23D), // Z4
    Color(0xFFFF5D5D), // Z5
  ];
}

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.neon,
      surface: AppColors.bg,
      secondary: AppColors.neon,
    ),
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.card,
      indicatorColor: AppColors.neon.withValues(alpha: 0.18),
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: AppColors.textSecondary),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.card,
      contentTextStyle: TextStyle(color: AppColors.textPrimary),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// 큰 숫자 타이포 (PRD: 숫자는 큰 타이포)
const kMetricStyle = TextStyle(
  color: AppColors.textPrimary,
  fontSize: 40,
  fontWeight: FontWeight.w900,
  height: 1.0,
  fontFeatures: [FontFeature.tabularFigures()],
);

const kMetricLabelStyle = TextStyle(
  color: AppColors.textSecondary,
  fontSize: 13,
);
