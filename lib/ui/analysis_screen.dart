import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'manual_add_screen.dart';
import 'run_detail_screen.dart';
import 'theme.dart';
import 'widgets/calendar_heatmap.dart';

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
          ? ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _sectionTitle('러닝 캘린더'),
                _heatmapCard(runs, context),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    '빈 날짜를 눌러 러닝 기록을 추가할 수 있습니다',
                    textAlign: TextAlign.center,
                    style: kMetricLabelStyle,
                  ),
                ),
              ],
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _sectionTitle('러닝 캘린더'),
                _heatmapCard(runs, context),
                _sectionTitle('주간 거리 (최근 8주)'),
                _weeklyBarChart(runs),
                _sectionTitle('평균 페이스 추이'),
                _caption(
                    '회차별 1km당 평균 페이스(분\'초")입니다. 선이 아래로 내려갈수록 더 빠르게 달린 것 — 기록이 좋아지고 있다는 뜻이에요.'),
                _paceChart(runs),
                if (vo2.isNotEmpty) ...[
                  _sectionTitle('최대 산소 섭취량 (VO₂max)'),
                  _caption(
                      '심폐 지구력 지표로, 몸이 1분 동안 쓸 수 있는 산소량(ml/kg/분)이에요. 높을수록 더 오래·빠르게 달릴 수 있고, 꾸준히 뛰면 서서히 올라갑니다. 일반 성인 35~45, 러너는 45~55 수준.'),
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

  Widget _caption(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(t,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                height: 1.4)),
      );

  Widget _heatmapCard(List<RunSession> runs, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CalendarHeatmap(
          runs: runs,
          onDayTap: (dayRuns) {
            if (dayRuns.length == 1) {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => RunDetailScreen(runId: dayRuns.first.id)),
              );
            } else {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.card,
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20))),
                builder: (ctx) => ListView(
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, 16 + MediaQuery.viewPaddingOf(ctx).bottom),
                  shrinkWrap: true,
                  children: [
                    Text(
                      DateFormat('M월 d일 (E)', 'ko')
                          .format(dayRuns.first.startTime),
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    ...dayRuns.map((r) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${r.distanceKm.toStringAsFixed(2)} km  ·  ${fmtPace(r.avgPaceSecPerKm)}',
                            style: const TextStyle(
                                color: AppColors.textPrimary),
                          ),
                          subtitle: Text(
                            DateFormat('HH:mm').format(r.startTime),
                            style: kMetricLabelStyle,
                          ),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textSecondary),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      RunDetailScreen(runId: r.id)),
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
                  builder: (_) => ManualAddScreen(initialDate: date)),
            );
          },
        ),
      ),
    );
  }

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
    // 30초(0.5분) 간격으로 눈금 정렬
    final paceMins = ordered.map((r) => r.avgPaceSecPerKm / 60.0);
    final minY = (paceMins.reduce((a, b) => a < b ? a : b) * 2).floor() / 2;
    final maxY = (paceMins.reduce((a, b) => a > b ? a : b) * 2).ceil() / 2;

    String fmtMin(double v) {
      final m = v.floor();
      final s = ((v - m) * 60).round();
      return "$m'${s.toString().padLeft(2, '0')}\"";
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 18, 18, 8),
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
                  color: Colors.white.withValues(alpha: 0.06),
                  strokeWidth: 1,
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            fmtMin(s.y),
                            const TextStyle(
                                color: AppColors.neon,
                                fontWeight: FontWeight.w700),
                          ))
                      .toList(),
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(
                  axisNameSize: 18,
                  axisNameWidget: Text('← 과거          최근 →',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                ),
                leftTitles: AxisTitles(
                  axisNameSize: 16,
                  axisNameWidget: const Text('페이스 (분/km)',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 10)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 0.5,
                    reservedSize: 44,
                    getTitlesWidget: (v, _) => Text(fmtMin(v),
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
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
                if (series.length >= 2) ...[
                  const SizedBox(width: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(up ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 13, color: deltaColor),
                        Text('${delta.abs().toStringAsFixed(1)} (90일)',
                            style: TextStyle(
                                color: deltaColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
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
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map((s) => LineTooltipItem(
                                  s.y.toStringAsFixed(1),
                                  TextStyle(
                                      color: AppColors.zoneColors[1],
                                      fontWeight: FontWeight.w700),
                                ))
                            .toList(),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      bottomTitles: const AxisTitles(
                        axisNameSize: 18,
                        axisNameWidget: Text('← 과거          최근 →',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 10)),
                      ),
                      leftTitles: AxisTitles(
                        axisNameSize: 16,
                        axisNameWidget: const Text('ml/kg/분',
                            style: TextStyle(
                                color: AppColors.textSecondary, fontSize: 10)),
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1,
                          reservedSize: 42,
                          getTitlesWidget: (v, _) => Text(
                            v.toStringAsFixed(1),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 10),
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
