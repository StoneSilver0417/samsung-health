import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../theme.dart';

/// 최근 8주간 주별 러닝 거리 막대 차트 카드
class WeeklyVolumeChartCard extends StatelessWidget {
  final List<RunSession> runs;

  const WeeklyVolumeChartCard({super.key, required this.runs});

  @override
  Widget build(BuildContext context) {
    final thisWeek = StatsSummary.weekStart(DateTime.now());
    final weeks = List.generate(
        8, (i) => thisWeek.subtract(Duration(days: 7 * (7 - i))));
    final weeklyKm = <DateTime, double>{};
    for (final r in runs) {
      final w = StatsSummary.weekStart(r.startTime);
      weeklyKm[w] = (weeklyKm[w] ?? 0) + r.distanceKm;
    }

    return Semantics(
      label: '최근 8주간 주별 러닝 거리 막대 그래프',
      child: Card(
        child: Padding(
          padding: AppSpacing.chartPadding,
          child: SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= weeks.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('M/d').format(weeks[i]),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                      '${rod.toY.toStringAsFixed(1)} km',
                      const TextStyle(
                        color: AppColors.neon,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(weeks.length, (i) {
                  final km = weeklyKm[weeks[i]] ?? 0;
                  final isThisWeek = weeks[i] == thisWeek;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: km,
                      width: 18,
                      borderRadius: AppRadius.br4,
                      color: isThisWeek
                          ? AppColors.neon
                          : AppColors.neon.withValues(alpha: 0.4),
                    ),
                  ]);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
