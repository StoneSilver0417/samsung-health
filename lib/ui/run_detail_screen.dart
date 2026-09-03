import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import '../services/gemini_service.dart';
import 'manual_add_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class RunDetailScreen extends ConsumerWidget {
  final String runId;

  const RunDetailScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsProvider).value ?? const <RunSession>[];
    final run = _findRun(runs, runId);
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
          if (run.sourceName == 'manual')
            IconButton(
              tooltip: '기록 수정',
              icon: const Icon(Icons.edit_outlined, color: AppColors.neon),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManualAddScreen(editing: run),
                  ),
                );
              },
            ),
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
          _AiSummaryCard(
            run: run,
            recentRuns: runs
                .where((r) => r.startTime.isBefore(run.startTime))
                .take(5)
                .toList(),
          ),
          if (run.hrSeries.length >= 2) ...[
            _sectionTitle('심박수'),
            _hrChart(run),
            _sectionTitle('심박존 분포'),
            _hrZones(run),
          ],
          _sectionTitle('러닝 역학 & 심폐 효율'),
          _runningDynamicsCard(run),
          if (run.laps.isNotEmpty) ...[
            _sectionTitle('워치 랩 기록'),
            _laps(run),
          ],
          if (run.segments.isNotEmpty) ...[
            _sectionTitle('인터벌'),
            _segments(run),
          ],
        ],
      ),
    );
  }

  static RunSession? _findRun(List<RunSession> runs, String id) {
    for (final run in runs) {
      if (run.id == id) return run;
    }
    return null;
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
    final cells = <(String, String)>[
      (fmtDuration(run.durationSec), '시간'),
      (fmtPace(run.avgPaceSecPerKm), '평균 페이스'),
      if (run.avgHr != null) ('${run.avgHr!.round()}', '평균 심박'),
      if (run.maxHr != null) ('${run.maxHr!.round()}', '최고 심박'),
      if (run.cadenceSpm != null)
        ('${run.cadenceSpm!.round()}', '케이던스 spm'),
      if (run.elevationM != null)
        ('${run.elevationM!.round()} m', '상승고도'),
      if (run.calories != null) ('${run.calories!.round()}', 'kcal'),
      if (run.steps != null) ('${run.steps}', '걸음'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Text('${run.distanceKm.toStringAsFixed(2)} km',
                style: kMetricStyle.copyWith(color: AppColors.neon)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: cells
                  .map((c) => SizedBox(
                        width: 86,
                        child: Column(
                          children: [
                            Text(c.$1,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text(c.$2,
                                textAlign: TextAlign.center,
                                style: kMetricLabelStyle),
                          ],
                        ),
                      ))
                  .toList(),
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
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots
                      .map((s) => LineTooltipItem(
                            '${s.y.round()} bpm',
                            const TextStyle(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700),
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

  static final _segmentLabels = {
    'running': ('운동', AppColors.neon),
    'hiit': ('HIIT', AppColors.neon),
    'walking': ('회복', AppColors.textSecondary),
    'rest': ('회복', AppColors.textSecondary),
    'pause': ('일시정지', AppColors.textSecondary),
    'stretching': ('스트레칭', AppColors.zoneColors[0]),
    'other': ('구간', AppColors.textSecondary),
    'unknown': ('구간', AppColors.textSecondary),
  };

  /// 삼성헬스 인터벌 화면과 같은 구성: 세트 / 종류 / 시간 / 거리 / 페이스
  Widget _segments(RunSession run) {
    var setNo = 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: const [
                SizedBox(width: 30, child: Text('세트', style: kMetricLabelStyle)),
                SizedBox(width: 64, child: Text('종류', style: kMetricLabelStyle)),
                Expanded(
                    child: Text('시간',
                        textAlign: TextAlign.end, style: kMetricLabelStyle)),
                Expanded(
                    child: Text('거리(km)',
                        textAlign: TextAlign.end, style: kMetricLabelStyle)),
                Expanded(
                    child: Text('페이스(/km)',
                        textAlign: TextAlign.end, style: kMetricLabelStyle)),
              ],
            ),
            const Divider(height: 16, color: Colors.white12),
            ...run.segments.map((seg) {
              final (label, color) =
                  _segmentLabels[seg.type] ?? _segmentLabels['unknown']!;
              if (seg.isActive) setNo++;
              final rowStyle = TextStyle(
                color: seg.isActive
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight:
                    seg.isActive ? FontWeight.w800 : FontWeight.w500,
                fontSize: 14,
              );
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                        width: 30,
                        child: Text(seg.isActive ? '$setNo' : '',
                            style: rowStyle)),
                    SizedBox(
                      width: 64,
                      child: Text(label,
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 14)),
                    ),
                    Expanded(
                        child: Text(fmtDuration(seg.durationSec),
                            textAlign: TextAlign.end, style: rowStyle)),
                    Expanded(
                        child: Text(
                            (seg.distanceM / 1000).toStringAsFixed(2),
                            textAlign: TextAlign.end,
                            style: rowStyle)),
                    Expanded(
                        child: Text(
                            seg.paceSecPerKm > 0
                                ? fmtPace(seg.paceSecPerKm)
                                : '—',
                            textAlign: TextAlign.end,
                            style: rowStyle)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _runningDynamicsCard(RunSession run) {
    final stride = run.strideCm;
    final drift = run.cardiacDriftPct;
    final ratio = run.aerobicAnaerobicRatio;
    final load = run.trainingLoadScore;
    final recovery = run.recommendedRecoveryHours;

    String strideLabel = '걸음 데이터 없음';
    if (stride != null) {
      if (stride < 85) {
        strideLabel = '짧은 보폭 (케이던스 위주)';
      } else if (stride <= 115) {
        strideLabel = '효율적이고 안정적인 보폭';
      } else {
        strideLabel = '긴 보폭 (오버스트라이드 주의)';
      }
    }

    String driftLabel = '심박 데이터 부족';
    Color driftColor = AppColors.textSecondary;
    if (drift != null) {
      if (drift < 5.0) {
        driftLabel = '심폐 지구력 안정적 (우수)';
        driftColor = AppColors.neon;
      } else if (drift <= 10.0) {
        driftLabel = '정상 피로도 누적';
        driftColor = const Color(0xFFFFB23D);
      } else {
        driftLabel = '심폐 과부하 / 탈진 주의';
        driftColor = AppColors.danger;
      }
    }

    String loadLabel = '가벼운 회복 세션';
    if (load >= 150) {
      loadLabel = '극심한 한계 훈련';
    } else if (load >= 100) {
      loadLabel = '고강도 체력 향상 세션';
    } else if (load >= 60) {
      loadLabel = '최적 발전 트레이닝';
    } else if (load >= 30) {
      loadLabel = '유산소 유지 트레이닝';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('평균 보폭 (Stride)', style: kMetricLabelStyle),
                        const SizedBox(height: 6),
                        Text(
                          stride != null ? '${stride.round()} cm' : '—',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          strideLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: stride != null
                                ? AppColors.neonDim
                                : AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('심박 드리프트 (피로도)', style: kMetricLabelStyle),
                        const SizedBox(height: 6),
                        Text(
                          drift != null
                              ? '${drift >= 0 ? '+' : ''}${drift.toStringAsFixed(1)}%'
                              : '—',
                          style: TextStyle(
                            color: driftColor,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          driftLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: driftColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('훈련 성격 분석', style: kMetricLabelStyle),
                  Text(
                    '유산소 ${ratio.aerobicPct.round()}%  •  무산소 ${ratio.anaerobicPct.round()}%',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (ratio.aerobicPct * 10).round().clamp(1, 1000),
                        child: Container(color: const Color(0xFF4AD9A5)),
                      ),
                      if (ratio.anaerobicPct > 0)
                        Expanded(
                          flex:
                              (ratio.anaerobicPct * 10).round().clamp(1, 1000),
                          child: Container(color: const Color(0xFFFFB23D)),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.neon.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child:
                        const Icon(Icons.bolt, color: AppColors.neon, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '훈련 부하 $load pt',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '($loadLabel)',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '권장 회복 휴식: 약 $recovery시간',
                          style: const TextStyle(
                            color: AppColors.neonDim,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _laps(RunSession run) {
    const headerStyle = TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700);
    const rowStyle = TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w600);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Row(
              children: [
                SizedBox(width: 36, child: Text('랩', style: headerStyle)),
                Expanded(
                    child: Text('시간',
                        textAlign: TextAlign.end, style: headerStyle)),
                Expanded(
                    child: Text('거리',
                        textAlign: TextAlign.end, style: headerStyle)),
                Expanded(
                    child: Text('페이스',
                        textAlign: TextAlign.end, style: headerStyle)),
                Expanded(
                    child: Text('심박',
                        textAlign: TextAlign.end, style: headerStyle)),
              ],
            ),
            const Divider(color: Colors.white12, height: 16),
            ...run.laps.map((lap) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(
                        '#${lap.lapNumber}',
                        style: const TextStyle(
                            color: AppColors.neon,
                            fontWeight: FontWeight.w800),
                      ),
                    ),
                    Expanded(
                        child: Text(fmtDuration(lap.durationSec),
                            textAlign: TextAlign.end, style: rowStyle)),
                    Expanded(
                        child: Text(
                            '${lap.distanceKm.toStringAsFixed(2)} km',
                            textAlign: TextAlign.end,
                            style: rowStyle)),
                    Expanded(
                        child: Text(
                            lap.paceSecPerKm > 0
                                ? fmtPace(lap.paceSecPerKm)
                                : '—',
                            textAlign: TextAlign.end,
                            style: rowStyle)),
                    Expanded(
                        child: Text(
                            lap.avgHr != null
                                ? '${lap.avgHr!.round()} bpm'
                                : '—',
                            textAlign: TextAlign.end,
                            style: rowStyle)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Gemini API로 러닝 1회를 요약·코칭. 결과는 기기 로컬에 캐시되어 재호출을 피한다.
class _AiSummaryCard extends ConsumerStatefulWidget {
  final RunSession run;
  final List<RunSession> recentRuns;

  const _AiSummaryCard({required this.run, required this.recentRuns});

  @override
  ConsumerState<_AiSummaryCard> createState() => _AiSummaryCardState();
}

class _AiSummaryCardState extends ConsumerState<_AiSummaryCard> {
  final _service = GeminiService();
  String? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = ref.read(repoProvider).getAiSummary(widget.run.id);
  }

  Future<void> _generate() async {
    final apiKey = ref.read(repoProvider).getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('설정에서 Gemini API 키를 먼저 입력하세요'),
        action: SnackBarAction(
          label: '설정으로',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ));
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text =
          await _service.summarizeRun(apiKey, widget.run, widget.recentRuns);
      await ref.read(repoProvider).saveAiSummary(widget.run.id, text);
      if (!mounted) return;
      setState(() => _summary = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 16, color: AppColors.neon),
                const SizedBox(width: 6),
                const Text('AI 러닝 요약',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                else
                  TextButton(
                    onPressed: _generate,
                    child: Text(_summary == null ? '생성' : '다시 생성'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!,
                    style: const TextStyle(
                        color: AppColors.danger, fontSize: 12)),
              )
            else if (_summary != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_summary!,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13.5,
                        height: 1.5)),
              )
            else if (!_loading)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('버튼을 눌러 이 러닝에 대한 AI 코멘트를 받아보세요',
                    style: kMetricLabelStyle),
              ),
          ],
        ),
      ),
    );
  }
}
