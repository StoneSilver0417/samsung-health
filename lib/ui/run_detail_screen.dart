import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

class RunDetailScreen extends ConsumerWidget {
  final String runId;

  const RunDetailScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final run = ref.read(repoProvider).getById(runId);
    if (run == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('기록을 찾을 수 없습니다')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko').format(run.startTime)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.card,
                  title: const Text('기록 삭제'),
                  content: const Text('이 러닝 기록을 삭제할까요?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('삭제',
                            style: TextStyle(color: AppColors.danger))),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ref.read(runsProvider.notifier).deleteRun(runId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _header(run),
          if (run.hrSeries.length >= 2) ...[
            _sectionTitle('심박수'),
            _hrChart(run),
            _sectionTitle('심박존 분포'),
            _hrZones(run),
          ],
          if (run.splits.isNotEmpty) ...[
            _sectionTitle('스플릿'),
            _splits(run),
          ] else
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                '스플릿 데이터 없음 — 삼성헬스가 거리 시계열을 제공하지 않은 세션입니다',
                style: kMetricLabelStyle,
              ),
            ),
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

  Widget _header(RunSession run) {
    Widget cell(String value, String label) => Column(
          children: [
            Text(value,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            Text(label, style: kMetricLabelStyle),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('${run.distanceKm.toStringAsFixed(2)} km',
                style: kMetricStyle.copyWith(color: AppColors.neon)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                cell(fmtDuration(run.durationSec), '시간'),
                cell(fmtPace(run.avgPaceSecPerKm), '평균 페이스'),
                if (run.avgHr != null)
                  cell('${run.avgHr!.round()}', '평균 심박'),
                if (run.calories != null)
                  cell('${run.calories!.round()}', 'kcal'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hrChart(RunSession run) {
    final start = run.hrSeries.first.time;
    final spots = run.hrSeries
        .map((h) => FlSpot(
              h.time.difference(start).inSeconds / 60.0,
              h.bpm,
            ))
        .toList();
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
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 5,
                    getTitlesWidget: (v, _) => Text('${v.toInt()}분',
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
    );
  }

  Widget _hrZones(RunSession run) {
    final zones = hrZoneDistribution(run.hrSeries);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(5, (i) {
            final pct = zones[i];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 30,
                    child: Text('Z${i + 1}',
                        style: TextStyle(
                            color: AppColors.zoneColors[i],
                            fontWeight: FontWeight.w800)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
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
                    child: Text('${(pct * 100).round()}%',
                        textAlign: TextAlign.end, style: kMetricLabelStyle),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _splits(RunSession run) {
    final maxPace = run.splits
        .map((s) => s.paceSecPerKm)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: run.splits.map((s) {
            final isPartial = s.km != s.km.roundToDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      isPartial ? s.km.toStringAsFixed(2) : '${s.km.toInt()}',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        // 빠른 페이스일수록 긴 막대
                        value: maxPace > 0
                            ? (2 - s.paceSecPerKm / maxPace).clamp(0.15, 1.0)
                            : 0,
                        minHeight: 14,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                        color: AppColors.neon,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Text(fmtPace(s.paceSecPerKm),
                        textAlign: TextAlign.end,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                  SizedBox(
                    width: 44,
                    child: Text(
                      s.avgHr != null ? '${s.avgHr!.round()}♥' : '',
                      textAlign: TextAlign.end,
                      style: kMetricLabelStyle,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
