import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';

/// 최대 산소 섭취량 (VO₂max) 추이 카드 — 체력 증진의 정량 지표 (PRD 1.3)
class Vo2maxTrendChartCard extends StatelessWidget {
  final List<(DateTime, double)> series;

  const Vo2maxTrendChartCard({super.key, required this.series});

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = series.last;
    final delta = latest.$2 - series.first.$2;
    final spots = List.generate(
        series.length, (i) => FlSpot(i.toDouble(), series[i].$2));
    final values = series.map((e) => e.$2);
    final minY =
        (values.reduce((a, b) => a < b ? a : b) - 1).floorToDouble();
    final maxY =
        (values.reduce((a, b) => a > b ? a : b) + 1).ceilToDouble();

    final up = delta >= 0;
    final deltaColor = up ? AppColors.neon : AppColors.danger;

    return Semantics(
      label: '최대 산소 섭취량 VO2max: 최신 ${latest.$2.toStringAsFixed(1)} ml/kg/분',
      child: Card(
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    latest.$2.toStringAsFixed(1),
                    style: AppTypography.largeMetric.copyWith(
                      color: AppColors.zoneColors[1],
                    ),
                  ),
                  AppSpacing.gapW6,
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Text('ml/kg/분', style: AppTypography.metricLabel),
                  ),
                  if (series.length >= 2) ...[
                    AppSpacing.gapW10,
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            up ? Icons.arrow_upward : Icons.arrow_downward,
                            size: AppIconSizes.xs,
                            color: deltaColor,
                          ),
                          Text(
                            '${delta.abs().toStringAsFixed(1)} (90일)',
                            style: TextStyle(
                              color: deltaColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    DateFormat('M/d 기준').format(latest.$1),
                    style: AppTypography.metricLabel,
                  ),
                ],
              ),
              if (series.length >= 2) ...[
                AppSpacing.gapH12,
                SizedBox(
                  height: 120,
                  child: LineChart(
                    LineChartData(
                      minY: minY,
                      maxY: maxY,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots
                              .map((s) => LineTooltipItem(
                                    s.y.toStringAsFixed(1),
                                    TextStyle(
                                      color: AppColors.zoneColors[1],
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(),
                        rightTitles: const AxisTitles(),
                        bottomTitles: const AxisTitles(
                          axisNameSize: 18,
                          axisNameWidget: Text(
                            '← 과거          최근 →',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        leftTitles: AxisTitles(
                          axisNameSize: 16,
                          axisNameWidget: const Text(
                            'ml/kg/분',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            reservedSize: 42,
                            getTitlesWidget: (v, _) => Text(
                              v.toStringAsFixed(1),
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          color: AppColors.zoneColors[1],
                          barWidth: 2.5,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
