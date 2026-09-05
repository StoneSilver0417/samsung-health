import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../logic/stats.dart';
import '../../theme.dart';

/// 최근 6개월 월별 러닝 거리 막대 차트 카드
class MonthlyRunsChartCard extends StatelessWidget {
  final MonthlyStats stats;

  const MonthlyRunsChartCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final months = stats.monthlyKm;

    return Semantics(
      label: '최근 6개월 월별 러닝 거리 막대 그래프',
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
                        if (i < 0 || i >= months.length) {
                          return const SizedBox.shrink();
                        }
                        return Text(
                          DateFormat('M월').format(months[i].$1),
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
                barGroups: List.generate(months.length, (i) {
                  final isThisMonth = i == months.length - 1;
                  return BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                      toY: months[i].$2,
                      width: 22,
                      borderRadius: AppRadius.br4,
                      color: isThisMonth
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
