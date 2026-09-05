import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'analysis/widgets/goal_recommend_card.dart';
import 'analysis/widgets/monthly_runs_chart_card.dart';
import 'analysis/widgets/monthly_summary_card.dart';
import 'analysis/widgets/pace_trend_chart_card.dart';
import 'analysis/widgets/pb_records_card.dart';
import 'analysis/widgets/vo2max_trend_chart_card.dart';
import 'analysis/widgets/weekly_volume_chart_card.dart';
import 'manual_add_screen.dart';
import 'run_detail_screen.dart';
import 'theme.dart';
import 'widgets/calendar_heatmap.dart';

/// 추세 분석 (PRD 4.2) — Phase 1은 주간 거리 바차트 + 페이스 추이 + PB.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  /// 페이스 차트 Y축 범위 계산 (테스트 및 서브 위젯 호환)
  static (double min, double max) safePaceRange(Iterable<double> values) =>
      PaceTrendChartCard.safePaceRange(values);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsProvider).value ?? const <RunSession>[];
    final stats = ref.watch(statsProvider);
    final monthly = MonthlyStats.fromRuns(runs);
    final vo2 = ref.watch(vo2SeriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: runs.isEmpty
          ? ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.s32),
              children: [
                _sectionTitle('러닝 캘린더'),
                _heatmapCard(runs, context),
                const Padding(
                  padding: AppSpacing.screenPadding,
                  child: Text(
                    '빈 날짜를 눌러 러닝 기록을 추가할 수 있습니다',
                    textAlign: TextAlign.center,
                    style: AppTypography.metricLabel,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: AppSpacing.s32),
              children: [
                GoalRecommendCard(
                  stats: stats,
                  monthly: monthly,
                  recentRuns: runs,
                ),
                _sectionTitle('러닝 캘린더'),
                _heatmapCard(runs, context),
                _sectionTitle('이번 달'),
                MonthlySummaryCard(stats: monthly),
                _sectionTitle('지난달 대비'),
                MonthCompareCard(stats: monthly),
                _sectionTitle('월별 거리 추이'),
                _caption('이번 달을 포함한 최근 6개월의 월별 러닝 거리입니다.'),
                MonthlyRunsChartCard(stats: monthly),
                _sectionTitle('주간 거리 (최근 8주)'),
                WeeklyVolumeChartCard(runs: runs),
                _sectionTitle('평균 페이스 추이'),
                _caption(
                  '회차별 1km당 평균 페이스(분\'초")입니다. 선이 아래로 내려갈수록 더 빠르게 달린 것 — 기록이 좋아지고 있다는 뜻이에요.',
                ),
                PaceTrendChartCard(runs: runs),
                if (vo2.isNotEmpty) ...[
                  _sectionTitle('최대 산소 섭취량 (VO₂max)'),
                  _caption(
                    '심폐 지구력 지표로, 몸이 1분 동안 쓸 수 있는 산소량(ml/kg/분)이에요. 높을수록 더 오래·빠르게 달릴 수 있고, 꾸준히 뛰면 서서히 올라갑니다. 일반 성인 35~45, 러너는 45~55 수준.',
                  ),
                  Vo2maxTrendChartCard(series: vo2),
                ],
                _sectionTitle('개인 기록 (PB)'),
                PbRecordsCard(stats: stats),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: AppSpacing.sectionHeaderPadding,
        child: Text(t, style: AppTypography.titleMedium),
      );

  Widget _caption(String t) => Padding(
        padding: AppSpacing.captionPadding,
        child: Text(t, style: AppTypography.bodySmall),
      );

  Widget _heatmapCard(List<RunSession> runs, BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: CalendarHeatmap(
          runs: runs,
          onDayTap: (dayRuns) {
            if (dayRuns.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RunDetailScreen(runId: dayRuns.first.id),
                ),
              );
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.card,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.bottomSheetTopMedium,
                ),
                builder: (ctx) => ListView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.s16,
                    AppSpacing.s16,
                    AppSpacing.s16,
                    AppSpacing.s16 + MediaQuery.viewPaddingOf(ctx).bottom,
                  ),
                  shrinkWrap: true,
                  children: [
                    Text(
                      DateFormat('M월 d일 (E)', 'ko')
                          .format(dayRuns.first.startTime),
                      style: AppTypography.titleLarge.copyWith(fontSize: 16),
                    ),
                    AppSpacing.gapH8,
                    ...dayRuns.map((r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${r.distanceKm.toStringAsFixed(2)} km  ·  ${fmtPace(r.avgPaceSecPerKm)}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('HH:mm').format(r.startTime),
                            style: AppTypography.metricLabel,
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: AppColors.textSecondary,
                            size: AppIconSizes.md,
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RunDetailScreen(runId: r.id),
                              ),
                            );
                          },
                        )),
                  ],
                ),
              );
            }
          },
          onEmptyDayTap: (date) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManualAddScreen(initialDate: date),
              ),
            );
          },
        ),
      ),
    );
  }
}
