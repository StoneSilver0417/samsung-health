import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:runlog/core/theme/app_design_tokens.dart';
import 'package:runlog/core/theme/app_theme.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/ui/widgets/calendar_heatmap.dart';
import 'package:runlog/ui/widgets/level_card.dart';
import 'package:runlog/ui/widgets/run_card.dart';
import 'package:runlog/ui/widgets/weekly_ring.dart';

double _calculateLuminance(Color color) {
  // sRGB relative luminance calculation
  double channelLuminance(double c) {
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) * ((c + 0.055) / 1.055);
  }

  final r = channelLuminance(color.r);
  final g = channelLuminance(color.g);
  final b = channelLuminance(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color foreground, Color background) {
  final l1 = _calculateLuminance(foreground);
  final l2 = _calculateLuminance(background);
  final lighter = l1 > l2 ? l1 : l2;
  final darker = l1 > l2 ? l2 : l1;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko');
  });

  group('AppDesignTokens and ThemeExtension', () {
    test('default tokens match AppColors constants', () {
      const tokens = AppDesignTokens();
      expect(tokens.bg, equals(AppColors.bg));
      expect(tokens.surface, equals(AppColors.surface));
      expect(tokens.card, equals(AppColors.card));
      expect(tokens.cardElevated, equals(AppColors.cardElevated));
      expect(tokens.cardSubtle, equals(AppColors.cardSubtle));
      expect(tokens.neon, equals(AppColors.neon));
      expect(tokens.neonDim, equals(AppColors.neonDim));
      expect(tokens.textPrimary, equals(AppColors.textPrimary));
      expect(tokens.textSecondary, equals(AppColors.textSecondary));
      expect(tokens.danger, equals(AppColors.danger));
      expect(tokens.warning, equals(AppColors.warning));
    });

    test('copyWith updates specified token fields', () {
      const tokens = AppDesignTokens();
      final updated = tokens.copyWith(
        neon: const Color(0xFF00FF00),
        cardElevated: const Color(0xFF222222),
      );

      expect(updated.neon, equals(const Color(0xFF00FF00)));
      expect(updated.cardElevated, equals(const Color(0xFF222222)));
      expect(updated.bg, equals(tokens.bg));
      expect(updated.textPrimary, equals(tokens.textPrimary));
    });

    test('lerp correctly linearly interpolates between token sets', () {
      const tokens1 = AppDesignTokens(neon: Color(0xFF000000));
      const tokens2 = AppDesignTokens(neon: Color(0xFFFFFFFF));

      final lerped = tokens1.lerp(tokens2, 0.5);
      expect(lerped.neon.r, closeTo(0.5, 0.05));
    });

    test('buildAppTheme integrates AppDesignTokens extension and M3 config', () {
      final theme = buildAppTheme();
      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, equals(AppColors.bg));
      expect(theme.colorScheme.primary, equals(AppColors.neon));
      expect(theme.cardTheme.color, equals(AppColors.card));

      final extension = theme.extension<AppDesignTokens>();
      expect(extension, isNotNull);
      expect(extension!.neon, equals(AppColors.neon));
    });
  });

  group('WCAG Accessibility Contrast Ratios (Minimum 4.5:1)', () {
    test('textPrimary contrast ratio on dark background and card exceeds 10:1', () {
      final ratioOnBg = _contrastRatio(AppColors.textPrimary, AppColors.bg);
      final ratioOnCard = _contrastRatio(AppColors.textPrimary, AppColors.card);

      expect(ratioOnBg, greaterThan(10.0));
      expect(ratioOnCard, greaterThan(10.0));
    });

    test('textSecondary contrast ratio on dark background and card exceeds 4.5:1 (WCAG AA)', () {
      final ratioOnBg = _contrastRatio(AppColors.textSecondary, AppColors.bg);
      final ratioOnCard = _contrastRatio(AppColors.textSecondary, AppColors.card);

      expect(ratioOnBg, greaterThanOrEqualTo(4.5));
      expect(ratioOnCard, greaterThanOrEqualTo(4.5));
    });

    test('textTertiary contrast ratio on dark background and card exceeds 4.5:1', () {
      final ratioOnBg = _contrastRatio(AppColors.textTertiary, AppColors.bg);
      final ratioOnCard = _contrastRatio(AppColors.textTertiary, AppColors.card);

      expect(ratioOnBg, greaterThanOrEqualTo(4.5));
      expect(ratioOnCard, greaterThanOrEqualTo(4.5));
    });

    test('neon accent contrast ratio on dark background exceeds 10:1', () {
      final ratioOnBg = _contrastRatio(AppColors.neon, AppColors.bg);
      expect(ratioOnBg, greaterThan(10.0));
    });
  });

  group('Typography, Spacing, and Radius Scales', () {
    test('AppSpacing scales follow 4-pt grid', () {
      expect(AppSpacing.s4, equals(4.0));
      expect(AppSpacing.s8, equals(8.0));
      expect(AppSpacing.s12, equals(12.0));
      expect(AppSpacing.s16, equals(16.0));
      expect(AppSpacing.s20, equals(20.0));
      expect(AppSpacing.s24, equals(24.0));
      expect(AppSpacing.s32, equals(32.0));
    });

    test('AppRadius scales provide expected dimensions', () {
      expect(AppRadius.r4, equals(4.0));
      expect(AppRadius.r8, equals(8.0));
      expect(AppRadius.r12, equals(12.0));
      expect(AppRadius.r16, equals(16.0));
      expect(AppRadius.r20, equals(20.0));
      expect(AppRadius.r24, equals(24.0));
      expect(AppRadius.rFull, equals(999.0));
    });

    test('AppTypography metric styles contain tabular figures', () {
      expect(AppTypography.heroMetric.fontFeatures, isNotEmpty);
      expect(AppTypography.largeMetric.fontFeatures, isNotEmpty);
      expect(AppTypography.metric.fontFeatures, isNotEmpty);
      expect(AppTypography.metricSub.fontFeatures, isNotEmpty);
    });
  });

  group('UI Components Accessibility & Semantics', () {
    testWidgets('WeeklyRing renders Semantics with progress details', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: WeeklyRing(
              weekKm: 12.5,
              weekRuns: 2,
              goalKm: 15.0,
              goalRuns: 3,
            ),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('12.5km') &&
            widget.properties.label!.contains('2회'),
      );

      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('RunCard renders Semantics with session details', (tester) async {
      final run = RunSession(
        id: 'test-run-1',
        startTime: DateTime(2026, 9, 5, 21, 30),
        endTime: DateTime(2026, 9, 5, 22, 0),
        distanceM: 5200,
        durationSec: 1800,
        avgHr: 155,
        maxHr: 175,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: RunCard(run: run),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('5.20km') &&
            widget.properties.label!.contains('155bpm'),
      );

      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('LevelCard renders Semantics with runner level and total distance', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(
            body: LevelCard(totalKm: 120.0),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('레벨') &&
            widget.properties.label!.contains('120.0km'),
      );

      expect(semanticsFinder, findsOneWidget);
    });

    testWidgets('CalendarHeatmap renders Semantics on calendar day cells', (tester) async {
      final runs = [
        RunSession(
          id: 'test-heat-1',
          startTime: DateTime.now(),
          endTime: DateTime.now().add(const Duration(minutes: 30)),
          distanceM: 5000,
          durationSec: 1800,
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(
            body: CalendarHeatmap(runs: runs),
          ),
        ),
      );

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('5.0km 러닝'),
      );

      expect(semanticsFinder, findsAtLeastNWidgets(1));
    });
  });
}
