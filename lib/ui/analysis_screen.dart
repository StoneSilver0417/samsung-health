import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// 추세 분석 (PRD 4.2) — Phase 1은 주간 거리 바차트 + 페이스 추이 + PB.
class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsProvider).value ?? const <RunSession>[];
    final stats = ref.watch(statsProvider);
    final vo2 = ref.watch(vo2SeriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('분석')),
      body: runs.isEmpty
          ? const Center(child: Text('데이터가 없습니다', style: kMetricLabelStyle))
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _sectionTitle('주간 거리 (최근 8주)'),
                _weeklyBarChart(runs),
                _sectionTitle('평균 페이스 추이'),
                _paceChart(runs),
                if (vo2.isNotEmpty) ...[
                  _sectionTitle('최대 산소 섭취량 (VO₂max)'),
                  _vo2Card(vo2),
                ],
                _sectionTitle('개인 기록 (PB)'),
                _pbCard(stats),
              ],
            ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800)),
      );

  Widget _weeklyBarChart(List<RunSession> runs) {
    final thisWeek = StatsSummary.weekStart(DateTime.now());
    final weeks = List.generate(
        8, (i) => thisWeek.subtract(Duration(days: 7 * (7 - i))));
    final weeklyKm = <DateTime, double>{};
    for (final r in runs) {
      final w = StatsSummary.weekStart(r.startTime);
      weeklyKm[w] = (weeklyKm[w] ?? 0) + r.distanceKm;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 18, 8),
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
                      return Text(DateFormat('M/d').format(weeks[i]),
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10));
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, _, rod, _) => BarTooltipItem(
                    '${rod.toY.toStringAsFixed(1)} km',
                    const TextStyle(
                        color: AppColors.neon, fontWeight: FontWeight.w700),
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
                    borderRadius: BorderRadius.circular(5),
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
    );
  }

  Widget _paceChart(List<RunSession> runs) {
    final ordered = runs.reversed
        .where((r) => r.avgPaceSecPerKm > 0)
        .toList(); // 과거 → 최근
    if (ordered.length < 2) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('러닝 2회 이상부터 추이를 보여드려요', style: kMetricLabelStyle),
      );
    }
    final spots = List.generate(
      ordered.length,
      (i) => FlSpot(i.toDouble(), ordered[i].avgPaceSecPerKm / 60.0),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 18, 8),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (v) => FlLine(
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) {
                      final m = v.floor();
                      final s = ((v - m) * 60).round();
                      return Text("$m'${s.toString().padLeft(2, '0')}\"",
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 10));
                    },
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
    );
  }

  /// VO2max 추이 — 체력 증진의 정량 지표 (PRD 1.3)
  Widget _vo2Card(List<(DateTime, double)> series) {
    final latest = series.last;
    final spots = List.generate(
        series.length, (i) => FlSpot(i.toDouble(), series[i].$2));
    final values = series.map((e) => e.$2);
    final minY = values.reduce((a, b) => a < b ? a : b) - 1;
    final maxY = values.reduce((a, b) => a > b ? a : b) + 1;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(latest.$2.toStringAsFixed(1),
                    style: kMetricStyle.copyWith(
                        color: AppColors.zoneColors[1], fontSize: 34)),
                const SizedBox(width: 6),
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('ml/kg/분', style: kMetricLabelStyle),
                ),
                const Spacer(),
                Text(DateFormat('M/d 기준').format(latest.$1),
                    style: kMetricLabelStyle),
              ],
            ),
            if (series.length >= 2) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 120,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(),
                      rightTitles: AxisTitles(),
                      bottomTitles: AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles:
                            SideTitles(showTitles: true, reservedSize: 36),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
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
    );
  }

  Widget _pbCard(StatsSummary stats) {
    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(label, style: kMetricLabelStyle),
              const Spacer(),
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row('최장 거리', '${stats.longestRunKm.toStringAsFixed(2)} km'),
            row('최고 1km 페이스',
                stats.best1kPaceSec != null ? fmtPace(stats.best1kPaceSec!) : '—'),
            row('최고 5km+ 평균 페이스',
                stats.best5kPaceSec != null ? fmtPace(stats.best5kPaceSec!) : '—'),
            row('최다 주간 거리', '${stats.maxWeekKm.toStringAsFixed(1)} km'),
            row('총 러닝 시간', fmtDuration(stats.totalSec)),
          ],
        ),
      ),
    );
  }
}
