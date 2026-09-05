import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../theme.dart';

/// 심박수 시계열 라인 차트 카드
class RunDetailHrChartCard extends StatelessWidget {
  final RunSession run;

  const RunDetailHrChartCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    if (run.hrSeries.length < 2) {
      return const SizedBox.shrink();
    }

    final start = run.hrSeries.first.time;
    final spots = run.hrSeries
        .map((h) => FlSpot(
              h.time.difference(start).inSeconds / 60.0,
              h.bpm,
            ))
        .toList();

    return Semantics(
      label:
          '심박수 시계열 차트: 평균 ${run.avgHr?.round() ?? '-'}bpm, 최고 ${run.maxHr?.round() ?? '-'}bpm',
      child: Card(
        child: Padding(
          padding: AppSpacing.chartPadding,
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.borderFaint,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (v, _) => Text(
                        '${v.toInt()}분',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              '${s.y.round()} bpm',
                              const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.danger,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.danger.withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 심박존(Z1~Z5) 분포 카드
class RunDetailHrZonesCard extends StatelessWidget {
  final RunSession run;

  const RunDetailHrZonesCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    final zones = hrZoneDistribution(run.hrSeries);
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          children: List.generate(5, (i) {
            final pct = zones[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
              child: Semantics(
                label: '심박존 Z${i + 1}: ${(pct * 100).round()}%',
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        'Z${i + 1}',
                        style: TextStyle(
                          color: AppColors.zoneColors[i],
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: AppRadius.br4,
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 10,
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          color: AppColors.zoneColors[i],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(pct * 100).round()}%',
                        textAlign: TextAlign.end,
                        style: AppTypography.metricLabel,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
