import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/run_session.dart';
import '../../theme.dart';

/// 회차별 평균 페이스 추이 선 차트 카드
class PaceTrendChartCard extends StatelessWidget {
  final List<RunSession> runs;

  const PaceTrendChartCard({super.key, required this.runs});

  static (double min, double max) safePaceRange(Iterable<double> values) {
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final min = (minValue * 2).floor() / 2;
    final max = (maxValue * 2).ceil() / 2;
    return min == max ? (min - 0.5, max + 0.5) : (min, max);
  }

  static String _fmtMin(double v) {
    final m = v.floor();
    final s = ((v - m) * 60).round();
    return "$m'${s.toString().padLeft(2, '0')}\"";
  }

  @override
  Widget build(BuildContext context) {
    final ordered = runs.reversed
        .where((r) => r.avgPaceSecPerKm > 0)
        .toList(); // 과거 → 최근
    if (ordered.length < 2) {
      return const Padding(
        padding: AppSpacing.screenPadding,
        child: Text('러닝 2회 이상부터 추이를 보여드려요', style: AppTypography.metricLabel),
      );
    }
    final spots = List.generate(
      ordered.length,
      (i) => FlSpot(i.toDouble(), ordered[i].avgPaceSecPerKm / 60.0),
    );
    // 30초(0.5분) 간격으로 눈금 정렬
    final paceMins = ordered.map((r) => r.avgPaceSecPerKm / 60.0);
    final (minY, maxY) = safePaceRange(paceMins);

    return Semantics(
      label: '회차별 1km당 평균 페이스 변화 선 그래프',
      child: Card(
        child: Padding(
          padding: AppSpacing.chartPadding,
          child: SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 0.5,
                  getDrawingHorizontalLine: (v) => FlLine(
                    color: AppColors.borderFaint,
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots
                        .map((s) => LineTooltipItem(
                              _fmtMin(s.y),
                              const TextStyle(
                                color: AppColors.neon,
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
                      '페이스 (분/km)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 0.5,
                      reservedSize: 44,
                      getTitlesWidget: (v, _) => Text(
                        _fmtMin(v),
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
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.neon,
                    barWidth: 2.5,
                    dotData: const FlDotData(show: true),
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
