import 'package:flutter/material.dart';

/// App-wide design colors (Dark Neon theme for night runners)
@immutable
class AppColors {
  const AppColors._();

  // Background & Surfaces
  static const Color bg = Color(0xFF0E1116);
  static const Color surface = Color(0xFF161B22);
  static const Color card = Color(0xFF161B22);
  static const Color cardElevated = Color(0xFF1C222C);
  static const Color cardSubtle = Color(0xFF11141A);

  // Neon Accents
  static const Color neon = Color(0xFFC8FF3D);
  static const Color neonDim = Color(0xFF8BB22A);
  static const Color neonMuted = Color(0xFF4B5E1A);

  // Text Hierarchy (WCAG AA 4.5:1+ compliance)
  static const Color textPrimary = Color(0xFFF0F3F6);
  static const Color textSecondary = Color(0xFF9EABB8);
  static const Color textTertiary = Color(0xFF768390);
  static const Color textOnNeon = Color(0xFF0E1116);

  // Feedback & Cardio Status
  static const Color danger = Color(0xFFFF5D5D);
  static const Color warning = Color(0xFFFFB23D);
  static const Color cardioGreen = Color(0xFF4AD9A5);
  static const Color cardioBlue = Color(0xFF4A90D9);
  static const Color cardioPurple = Color(0xFFB07AFF);

  // Borders & Overlays
  static const Color borderSubtle = Color(0x1FFFFFFF); // white12
  static const Color borderFaint = Color(0x0FFFFFFF);  // white.alpha(0.06)
  static const Color borderFocused = Color(0x66C8FF3D);
  static const Color surfaceHighlight = Color(0x0AFFFFFF); // white.alpha(0.04)

  // Heart Rate Zones (Z1 ~ Z5)
  static const List<Color> zoneColors = [
    Color(0xFF4A90D9), // Z1: 회복 (Recovery)
    Color(0xFF4AD9A5), // Z2: 유산소 기초 (Aerobic Base)
    Color(0xFFC8FF3D), // Z3: 유산소 지구력 (Aerobic Endurance)
    Color(0xFFFFB23D), // Z4: 역치/무산소 (Threshold/Anaerobic)
    Color(0xFFFF5D5D), // Z5: 최대 심박 (Max HR)
  ];
}

/// 4-pt grid spacing tokens
@immutable
class AppSpacing {
  const AppSpacing._();

  static const double s4 = 4.0;
  static const double s6 = 6.0;
  static const double s8 = 8.0;
  static const double s10 = 10.0;
  static const double s12 = 12.0;
  static const double s14 = 14.0;
  static const double s16 = 16.0;
  static const double s18 = 18.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s28 = 28.0;
  static const double s32 = 32.0;

  // Pre-configured EdgeInsets
  static const EdgeInsets zero = EdgeInsets.zero;
  static const EdgeInsets all4 = EdgeInsets.all(s4);
  static const EdgeInsets all6 = EdgeInsets.all(s6);
  static const EdgeInsets all8 = EdgeInsets.all(s8);
  static const EdgeInsets all12 = EdgeInsets.all(s12);
  static const EdgeInsets all14 = EdgeInsets.all(s14);
  static const EdgeInsets all16 = EdgeInsets.all(s16);
  static const EdgeInsets all18 = EdgeInsets.all(s18);
  static const EdgeInsets all20 = EdgeInsets.all(s20);
  static const EdgeInsets all24 = EdgeInsets.all(s24);
  static const EdgeInsets all32 = EdgeInsets.all(s32);

  static const EdgeInsets screenPadding = EdgeInsets.all(s20);
  static const EdgeInsets screenHorizontal = EdgeInsets.symmetric(horizontal: s20);
  static const EdgeInsets cardMargin = EdgeInsets.symmetric(horizontal: s16, vertical: s6);
  static const EdgeInsets cardPadding = EdgeInsets.all(s16);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(s18);
  static const EdgeInsets sectionHeaderPadding = EdgeInsets.fromLTRB(s20, s18, s20, s6);
  static const EdgeInsets sectionHeaderTopPadding = EdgeInsets.fromLTRB(s20, s18, s20, s4);
  static const EdgeInsets captionPadding = EdgeInsets.fromLTRB(s20, 0, s20, s8);
  static const EdgeInsets chartPadding = EdgeInsets.fromLTRB(s12, s18, s18, s8);
  static const EdgeInsets bottomSheetPadding = EdgeInsets.fromLTRB(s28, s16, s28, s28);

  // Gap SizedBoxes
  static const SizedBox gapW4 = SizedBox(width: s4);
  static const SizedBox gapW6 = SizedBox(width: s6);
  static const SizedBox gapW8 = SizedBox(width: s8);
  static const SizedBox gapW10 = SizedBox(width: s10);
  static const SizedBox gapW12 = SizedBox(width: s12);
  static const SizedBox gapW14 = SizedBox(width: s14);
  static const SizedBox gapW16 = SizedBox(width: s16);

  static const SizedBox gapH2 = SizedBox(height: 2.0);
  static const SizedBox gapH4 = SizedBox(height: s4);
  static const SizedBox gapH6 = SizedBox(height: s6);
  static const SizedBox gapH8 = SizedBox(height: s8);
  static const SizedBox gapH10 = SizedBox(height: s10);
  static const SizedBox gapH12 = SizedBox(height: s12);
  static const SizedBox gapH14 = SizedBox(height: s14);
  static const SizedBox gapH16 = SizedBox(height: s16);
  static const SizedBox gapH18 = SizedBox(height: s18);
  static const SizedBox gapH20 = SizedBox(height: s20);
  static const SizedBox gapH24 = SizedBox(height: s24);
  static const SizedBox gapH28 = SizedBox(height: s28);
  static const SizedBox gapH32 = SizedBox(height: s32);
}

/// Border radius tokens
@immutable
class AppRadius {
  const AppRadius._();

  static const double r4 = 4.0;
  static const double r6 = 6.0;
  static const double r8 = 8.0;
  static const double r12 = 12.0;
  static const double r16 = 16.0;
  static const double r20 = 20.0;
  static const double r24 = 24.0;
  static const double rFull = 999.0;

  static const Radius radius4 = Radius.circular(r4);
  static const Radius radius6 = Radius.circular(r6);
  static const Radius radius8 = Radius.circular(r8);
  static const Radius radius12 = Radius.circular(r12);
  static const Radius radius16 = Radius.circular(r16);
  static const Radius radius20 = Radius.circular(r20);
  static const Radius radius24 = Radius.circular(r24);
  static const Radius radiusFull = Radius.circular(rFull);

  static const BorderRadius br4 = BorderRadius.all(radius4);
  static const BorderRadius br6 = BorderRadius.all(radius6);
  static const BorderRadius br8 = BorderRadius.all(radius8);
  static const BorderRadius br12 = BorderRadius.all(radius12);
  static const BorderRadius br16 = BorderRadius.all(radius16);
  static const BorderRadius br20 = BorderRadius.all(radius20);
  static const BorderRadius br24 = BorderRadius.all(radius24);
  static const BorderRadius brFull = BorderRadius.all(radiusFull);

  static const BorderRadius bottomSheetTop = BorderRadius.vertical(top: radius24);
  static const BorderRadius bottomSheetTopMedium = BorderRadius.vertical(top: radius20);
}

/// Icon size tokens
@immutable
class AppIconSizes {
  const AppIconSizes._();

  static const double xs = 13.0;
  static const double sm = 16.0;
  static const double md = 18.0;
  static const double standard = 20.0;
  static const double lg = 24.0;
  static const double xl = 30.0;
  static const double hero = 58.0;
}

/// Typography scale tokens
@immutable
class AppTypography {
  const AppTypography._();

  // Metrics (Tabular figures)
  static const TextStyle heroMetric = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle largeMetric = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 34,
    fontWeight: FontWeight.w900,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metric = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w900,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricSub = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 19,
    fontWeight: FontWeight.w900,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const TextStyle metricLabel = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  // Headlines & Titles
  static const TextStyle titleLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  static const TextStyle titleMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  static const TextStyle titleSmall = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w800,
    height: 1.3,
  );

  // Body Texts
  static const TextStyle bodyLarge = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    color: AppColors.textPrimary,
    fontSize: 13.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Captions & Micro Labels
  static const TextStyle caption = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );

  static const TextStyle captionBold = TextStyle(
    color: AppColors.textSecondary,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    height: 1.3,
  );

  static const TextStyle badge = TextStyle(
    color: Colors.black,
    fontSize: 10,
    fontWeight: FontWeight.w900,
    height: 1.2,
  );
}

/// ThemeExtension implementation for typed token access through BuildContext
@immutable
class AppDesignTokens extends ThemeExtension<AppDesignTokens> {
  final Color bg;
  final Color surface;
  final Color card;
  final Color cardElevated;
  final Color cardSubtle;
  final Color neon;
  final Color neonDim;
  final Color neonMuted;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color danger;
  final Color warning;
  final Color cardioGreen;
  final Color cardioBlue;
  final Color cardioPurple;

  const AppDesignTokens({
    this.bg = AppColors.bg,
    this.surface = AppColors.surface,
    this.card = AppColors.card,
    this.cardElevated = AppColors.cardElevated,
    this.cardSubtle = AppColors.cardSubtle,
    this.neon = AppColors.neon,
    this.neonDim = AppColors.neonDim,
    this.neonMuted = AppColors.neonMuted,
    this.textPrimary = AppColors.textPrimary,
    this.textSecondary = AppColors.textSecondary,
    this.textTertiary = AppColors.textTertiary,
    this.danger = AppColors.danger,
    this.warning = AppColors.warning,
    this.cardioGreen = AppColors.cardioGreen,
    this.cardioBlue = AppColors.cardioBlue,
    this.cardioPurple = AppColors.cardioPurple,
  });

  static AppDesignTokens of(BuildContext context) {
    return Theme.of(context).extension<AppDesignTokens>() ?? const AppDesignTokens();
  }

  @override
  AppDesignTokens copyWith({
    Color? bg,
    Color? surface,
    Color? card,
    Color? cardElevated,
    Color? cardSubtle,
    Color? neon,
    Color? neonDim,
    Color? neonMuted,
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? danger,
    Color? warning,
    Color? cardioGreen,
    Color? cardioBlue,
    Color? cardioPurple,
  }) {
    return AppDesignTokens(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      card: card ?? this.card,
      cardElevated: cardElevated ?? this.cardElevated,
      cardSubtle: cardSubtle ?? this.cardSubtle,
      neon: neon ?? this.neon,
      neonDim: neonDim ?? this.neonDim,
      neonMuted: neonMuted ?? this.neonMuted,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      danger: danger ?? this.danger,
      warning: warning ?? this.warning,
      cardioGreen: cardioGreen ?? this.cardioGreen,
      cardioBlue: cardioBlue ?? this.cardioBlue,
      cardioPurple: cardioPurple ?? this.cardioPurple,
    );
  }

  @override
  AppDesignTokens lerp(ThemeExtension<AppDesignTokens>? other, double t) {
    if (other is! AppDesignTokens) return this;
    return AppDesignTokens(
      bg: Color.lerp(bg, other.bg, t) ?? bg,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      card: Color.lerp(card, other.card, t) ?? card,
      cardElevated: Color.lerp(cardElevated, other.cardElevated, t) ?? cardElevated,
      cardSubtle: Color.lerp(cardSubtle, other.cardSubtle, t) ?? cardSubtle,
      neon: Color.lerp(neon, other.neon, t) ?? neon,
      neonDim: Color.lerp(neonDim, other.neonDim, t) ?? neonDim,
      neonMuted: Color.lerp(neonMuted, other.neonMuted, t) ?? neonMuted,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t) ?? textTertiary,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      cardioGreen: Color.lerp(cardioGreen, other.cardioGreen, t) ?? cardioGreen,
      cardioBlue: Color.lerp(cardioBlue, other.cardioBlue, t) ?? cardioBlue,
      cardioPurple: Color.lerp(cardioPurple, other.cardioPurple, t) ?? cardioPurple,
    );
  }
}

/// BuildContext extension for swift token consumption
extension ThemeTokensContextExtension on BuildContext {
  AppDesignTokens get tokens => AppDesignTokens.of(this);
}
