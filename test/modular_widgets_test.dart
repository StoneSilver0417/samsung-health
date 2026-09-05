import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/providers.dart';
import 'package:runlog/ui/analysis/widgets/goal_recommend_card.dart';
import 'package:runlog/ui/analysis/widgets/monthly_runs_chart_card.dart';
import 'package:runlog/ui/analysis/widgets/monthly_summary_card.dart';
import 'package:runlog/ui/analysis/widgets/pace_trend_chart_card.dart';
import 'package:runlog/ui/analysis/widgets/pb_records_card.dart';
import 'package:runlog/ui/analysis/widgets/vo2max_trend_chart_card.dart';
import 'package:runlog/ui/analysis/widgets/weekly_volume_chart_card.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_ai_summary_card.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_delete_dialog.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_hero_header.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_hr_chart_card.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_laps_table_card.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_metrics_grid.dart';
import 'package:runlog/ui/run_detail/widgets/run_detail_running_dynamics_card.dart';
import 'package:runlog/ui/theme.dart';
import 'package:runlog/ui/widgets/ai_report_presentation.dart';

import 'support/in_memory_run_repository.dart';

Widget _wrapWidget({required Widget child, InMemoryRunRepository? repo}) {
  return ProviderScope(
    overrides: [if (repo != null) repoProvider.overrideWithValue(repo)],
    child: MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

RunSession _sampleSession({
  String id = 's1',
  DateTime? startTime,
  double km = 5.0,
  int durationSec = 1800,
  double? avgHr = 150,
  double? maxHr = 175,
  double? elevationM = 25,
  double? calories = 350,
  int? steps = 4950,
  List<RunLap> laps = const [],
  List<RunSegment> segments = const [],
  List<HrSample> hrSeries = const [],
}) {
  final start = startTime ?? DateTime(2026, 8, 1, 20);
  return RunSession(
    id: id,
    startTime: start,
    endTime: start.add(Duration(seconds: durationSec)),
    distanceM: km * 1000,
    durationSec: durationSec,
    avgHr: avgHr,
    maxHr: maxHr,
    elevationM: elevationM,
    calories: calories,
    steps: steps,
    laps: laps,
    segments: segments,
    hrSeries: hrSeries,
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  group('AI report presentation', () {
    test('extracts a named section without leaking following sections', () {
      const report = '''[핵심 요약]
안정적인 이븐 페이스 러닝입니다.

[페이스 & 심박 분석]
후반 심박이 상승했습니다.''';

      expect(extractAiReportSection(report, '핵심 요약'), '안정적인 이븐 페이스 러닝입니다.');
    });

    test('falls back to the first report paragraph for malformed output', () {
      const report = '첫 번째 요약 문장입니다.\n두 번째 요약 문장입니다.\n\n상세 분석';

      expect(
        extractAiReportSection(report, '핵심 요약'),
        '첫 번째 요약 문장입니다.\n두 번째 요약 문장입니다.',
      );
    });
  });

  group('Analysis Sub-Widgets Isolated Tests', () {
    testWidgets(
      'MonthlySummaryCard & MonthCompareCard render metrics and comparisons',
      (tester) async {
        final runs = [
          _sampleSession(
            id: 'r1',
            startTime: DateTime(2026, 8, 1, 20),
            km: 10.0,
            durationSec: 3600,
          ),
          _sampleSession(
            id: 'r2',
            startTime: DateTime(2026, 7, 15, 20),
            km: 8.0,
            durationSec: 3000,
          ),
        ];
        final monthly = MonthlyStats.fromRuns(runs, now: DateTime(2026, 8, 10));

        await tester.pumpWidget(
          _wrapWidget(
            child: Column(
              children: [
                MonthlySummaryCard(stats: monthly),
                MonthCompareCard(stats: monthly),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('10.0'), findsOneWidget);
        expect(find.text('러닝 횟수'), findsOneWidget);
        expect(find.text('1회'), findsWidgets);
        expect(find.text('거리'), findsOneWidget);
        expect(find.text('2.0 km'), findsOneWidget); // 10 - 8 delta
      },
    );

    testWidgets('MonthCompareCard shows fallback when no last month runs', (
      tester,
    ) async {
      final runs = [
        _sampleSession(id: 'r1', startTime: DateTime(2026, 8, 1, 20), km: 5.0),
      ];
      final monthly = MonthlyStats.fromRuns(runs, now: DateTime(2026, 8, 10));

      await tester.pumpWidget(
        _wrapWidget(child: MonthCompareCard(stats: monthly)),
      );
      await tester.pumpAndSettle();

      expect(find.text('지난달 러닝 기록이 없어 비교할 수 없습니다'), findsOneWidget);
    });

    testWidgets('MonthlyRunsChartCard renders with semantics', (tester) async {
      final runs = [
        _sampleSession(id: 'r1', startTime: DateTime(2026, 8, 1, 20), km: 5.0),
      ];
      final monthly = MonthlyStats.fromRuns(runs, now: DateTime(2026, 8, 10));

      await tester.pumpWidget(
        _wrapWidget(child: MonthlyRunsChartCard(stats: monthly)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('최근 6개월 월별 러닝 거리 막대 그래프'), findsOneWidget);
    });

    testWidgets('WeeklyVolumeChartCard renders with semantics', (tester) async {
      final runs = [
        _sampleSession(id: 'r1', startTime: DateTime.now(), km: 5.0),
      ];

      await tester.pumpWidget(
        _wrapWidget(child: WeeklyVolumeChartCard(runs: runs)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('최근 8주간 주별 러닝 거리 막대 그래프'), findsOneWidget);
    });

    testWidgets('PaceTrendChartCard shows notice when < 2 runs', (
      tester,
    ) async {
      final runs = [
        _sampleSession(id: 'r1', startTime: DateTime.now(), km: 5.0),
      ];

      await tester.pumpWidget(
        _wrapWidget(child: PaceTrendChartCard(runs: runs)),
      );
      await tester.pumpAndSettle();

      expect(find.text('러닝 2회 이상부터 추이를 보여드려요'), findsOneWidget);
    });

    testWidgets('PaceTrendChartCard renders chart when >= 2 runs', (
      tester,
    ) async {
      final runs = [
        _sampleSession(
          id: 'r1',
          startTime: DateTime(2026, 8, 1, 20),
          km: 5.0,
          durationSec: 1800,
        ),
        _sampleSession(
          id: 'r2',
          startTime: DateTime(2026, 8, 3, 20),
          km: 5.0,
          durationSec: 1700,
        ),
      ];

      await tester.pumpWidget(
        _wrapWidget(child: PaceTrendChartCard(runs: runs)),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('회차별 1km당 평균 페이스 변화 선 그래프'), findsOneWidget);
    });

    testWidgets('Vo2maxTrendChartCard renders latest metric and chart', (
      tester,
    ) async {
      final series = [
        (DateTime(2026, 7, 1), 44.0),
        (DateTime(2026, 8, 1), 46.5),
      ];

      await tester.pumpWidget(
        _wrapWidget(child: Vo2maxTrendChartCard(series: series)),
      );
      await tester.pumpAndSettle();

      expect(find.text('46.5'), findsOneWidget);
      expect(find.text('ml/kg/분'), findsWidgets);
      expect(find.text('2.5 (90일)'), findsOneWidget);
    });

    testWidgets('PbRecordsCard renders personal best records correctly', (
      tester,
    ) async {
      final runs = [
        _sampleSession(
          id: 'r1',
          startTime: DateTime(2026, 8, 1, 20),
          km: 10.0,
          durationSec: 3600,
        ),
      ];
      final stats = StatsSummary.fromRuns(runs);

      await tester.pumpWidget(_wrapWidget(child: PbRecordsCard(stats: stats)));
      await tester.pumpAndSettle();

      expect(find.text('최장 거리'), findsOneWidget);
      expect(find.text('10.00 km'), findsOneWidget);
      expect(find.text('총 러닝 시간'), findsOneWidget);
      expect(find.text('1:00:00'), findsOneWidget);
    });

    testWidgets('GoalRecommendCard displays recommendations or guide', (
      tester,
    ) async {
      final repo = InMemoryRunRepository();
      await repo.saveGoalRecommendation(
        '[다음 1~2주 목표]\n5km 25분 목표 추천\n\n[추천 세션 구성]\n이지런 2회',
        DateTime(2026, 8, 1, 12),
      );

      final runs = [
        _sampleSession(id: 'r1', startTime: DateTime(2026, 8, 1, 20), km: 5.0),
      ];
      final stats = StatsSummary.fromRuns(runs);
      final monthly = MonthlyStats.fromRuns(runs);

      await tester.pumpWidget(
        _wrapWidget(
          repo: repo,
          child: GoalRecommendCard(
            stats: stats,
            monthly: monthly,
            recentRuns: runs,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('다음 목표 AI 제안'), findsOneWidget);
      expect(find.text('5km 25분 목표 추천'), findsOneWidget);
      expect(find.text('이지런 2회'), findsNothing);

      await tester.tap(find.byKey(const Key('ai-goal-full-report-button')));
      await tester.pumpAndSettle();

      expect(find.text('AI 맞춤 다음 목표 가이드'), findsOneWidget);
      expect(find.textContaining('이지런 2회'), findsOneWidget);
    });
  });

  group('RunDetail Sub-Widgets Isolated Tests', () {
    testWidgets(
      'RunDetailHeroHeader and MetricsGrid render all session details',
      (tester) async {
        final run = _sampleSession(
          id: 'rd1',
          km: 7.5,
          durationSec: 2700,
          avgHr: 148,
          maxHr: 165,
          elevationM: 30,
          calories: 520,
          steps: 7650,
        );

        await tester.pumpWidget(
          _wrapWidget(
            child: Column(
              children: [
                RunDetailHeroHeader(run: run),
                RunDetailMetricsGrid(run: run),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('7.50 km'), findsOneWidget);
        expect(find.text('45:00'), findsWidgets);
        expect(find.text('6\'00"'), findsWidgets);
        expect(find.text('148'), findsWidgets);
        expect(find.text('165'), findsWidgets);
        expect(find.text('170'), findsWidgets);
        expect(find.text('98 cm'), findsWidgets);
        expect(find.text('30 m'), findsWidgets);
        expect(find.text('520'), findsWidgets);
        expect(find.text('7650'), findsWidgets);
      },
    );

    testWidgets('RunDetailAiSummaryCard renders cached summary or guide', (
      tester,
    ) async {
      final repo = InMemoryRunRepository();
      await repo.saveAiSummary(
        'rd_ai',
        '[핵심 요약]\n우수한 인터벌 트레이닝이었습니다.\n\n'
            '[페이스 & 심박 분석]\n후반 페이스가 향상됐습니다.',
      );

      final run = _sampleSession(id: 'rd_ai', km: 5.0);

      await tester.pumpWidget(
        _wrapWidget(
          repo: repo,
          child: RunDetailAiSummaryCard(run: run, recentRuns: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI 코치 분석 요약'), findsOneWidget);
      expect(find.text('우수한 인터벌 트레이닝이었습니다.'), findsOneWidget);
      expect(find.textContaining('후반 페이스가 향상됐습니다.'), findsNothing);

      await tester.tap(find.byKey(const Key('ai-run-full-report-button')));
      await tester.pumpAndSettle();

      expect(find.text('AI 러닝 상세 분석 보고서'), findsOneWidget);
      expect(find.textContaining('후반 페이스가 향상됐습니다.'), findsOneWidget);
    });

    testWidgets(
      'RunDetailRunningDynamicsCard displays stride and drift indicators',
      (tester) async {
        final run = _sampleSession(
          id: 'rd2',
          km: 5.0,
          durationSec: 1800,
          steps: 4545,
          hrSeries: [
            HrSample(time: DateTime(2026, 8, 1, 20, 0), bpm: 140),
            HrSample(time: DateTime(2026, 8, 1, 20, 10), bpm: 142),
            HrSample(time: DateTime(2026, 8, 1, 20, 20), bpm: 145),
            HrSample(time: DateTime(2026, 8, 1, 20, 30), bpm: 148),
          ],
        );

        await tester.pumpWidget(
          _wrapWidget(child: RunDetailRunningDynamicsCard(run: run)),
        );
        await tester.pumpAndSettle();

        expect(find.text('평균 보폭 (Stride)'), findsOneWidget);
        expect(find.text('110 cm'), findsOneWidget);
        expect(find.text('효율적인 안정적 보폭'), findsOneWidget);
        expect(find.text('심박 드리프트 (피로도)'), findsOneWidget);
        expect(find.textContaining('훈련 부하'), findsOneWidget);
      },
    );

    testWidgets(
      'RunDetailHrChartCard and HrZonesCard render HR chart and Z1~Z5 zones',
      (tester) async {
        final run = _sampleSession(
          id: 'rd3',
          avgHr: 150,
          maxHr: 170,
          hrSeries: [
            HrSample(time: DateTime(2026, 8, 1, 20, 0), bpm: 130),
            HrSample(time: DateTime(2026, 8, 1, 20, 10), bpm: 145),
            HrSample(time: DateTime(2026, 8, 1, 20, 20), bpm: 160),
          ],
        );

        await tester.pumpWidget(
          _wrapWidget(
            child: Column(
              children: [
                RunDetailHrChartCard(run: run),
                RunDetailHrZonesCard(run: run),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel('심박수 시계열 차트: 평균 150bpm, 최고 170bpm'),
          findsOneWidget,
        );
        expect(find.text('Z1'), findsOneWidget);
        expect(find.text('Z5'), findsOneWidget);
      },
    );

    testWidgets(
      'RunDetailLapsTableCard and SegmentsCard render laps and intervals',
      (tester) async {
        final run = _sampleSession(
          id: 'rd4',
          laps: [
            RunLap(
              lapNumber: 1,
              startTime: DateTime(2026, 8, 1, 20),
              endTime: DateTime(2026, 8, 1, 20, 5),
              distanceM: 1000,
              avgHr: 140,
            ),
          ],
          segments: [
            RunSegment(
              startTime: DateTime(2026, 8, 1, 20),
              endTime: DateTime(2026, 8, 1, 20, 5),
              type: 'running',
              distanceM: 1000,
            ),
          ],
        );

        await tester.pumpWidget(
          _wrapWidget(
            child: Column(
              children: [
                RunDetailLapsTableCard(run: run),
                RunDetailSegmentsCard(run: run),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('#1'), findsOneWidget);
        expect(find.text('1.00 km'), findsOneWidget);
        expect(find.text('세트'), findsOneWidget);
        expect(find.text('운동'), findsOneWidget);
      },
    );

    testWidgets(
      'RunDetailDeleteDialog shows confirm dialog and returns decision',
      (tester) async {
        bool? result;

        await tester.pumpWidget(
          _wrapWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await RunDetailDeleteDialog.show(context);
                },
                child: const Text('삭제 열기'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('삭제 열기'));
        await tester.pumpAndSettle();

        expect(find.text('기록 삭제'), findsOneWidget);
        expect(find.text('이 러닝 기록을 삭제할까요?'), findsOneWidget);

        await tester.tap(find.text('삭제'));
        await tester.pumpAndSettle();

        expect(result, isTrue);
      },
    );
  });
}
