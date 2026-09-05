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
        body: const Center(
          child: Text('기록을 찾을 수 없습니다', style: AppTypography.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko').format(run.startTime)),
        actions: [
          if (run.sourceName == 'manual')
            IconButton(
              tooltip: '기록 수정',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.neon,
                size: AppIconSizes.lg,
              ),
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
            tooltip: '기록 삭제',
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.danger,
              size: AppIconSizes.lg,
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.card,
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadius.br20,
                  ),
                  title: const Text('기록 삭제', style: AppTypography.titleLarge),
                  content: const Text(
                    '이 러닝 기록을 삭제할까요?',
                    style: AppTypography.bodySmall,
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
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
        padding: const EdgeInsets.only(bottom: AppSpacing.s32),
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
        padding: AppSpacing.sectionHeaderPadding,
        child: Text(t, style: AppTypography.titleMedium),
      );

  Widget _header(RunSession run) {
    final cells = <(String, String)>[
      (fmtDuration(run.durationSec), '시간'),
      (fmtPace(run.avgPaceSecPerKm), '평균 페이스'),
      if (run.avgHr != null) ('${run.avgHr!.round()}', '평균 심박'),
      if (run.maxHr != null) ('${run.maxHr!.round()}', '최고 심박'),
      if (run.cadenceSpm != null)
        ('${run.cadenceSpm!.round()}', '케이던스 spm'),
      if (run.strideCm != null)
        ('${run.strideCm!.round()} cm', '평균 보폭'),
      if (run.elevationM != null)
        ('${run.elevationM!.round()} m', '상승고도'),
      if (run.calories != null) ('${run.calories!.round()}', 'kcal'),
      if (run.steps != null && run.cadenceSpm != null)
        ('${run.steps}', '총 걸음'),
    ];

    return Semantics(
      label: '러닝 요약: 거리 ${run.distanceKm.toStringAsFixed(2)}km, 시간 ${fmtDuration(run.durationSec)}, 평균 페이스 ${fmtPace(run.avgPaceSecPerKm)}',
      child: Card(
        color: AppColors.cardElevated,
        child: Padding(
          padding: AppSpacing.cardPaddingLarge,
          child: Column(
            children: [
              Text(
                '${run.distanceKm.toStringAsFixed(2)} km',
                style: AppTypography.heroMetric.copyWith(color: AppColors.neon),
              ),
              AppSpacing.gapH16,
              Wrap(
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s16,
                alignment: WrapAlignment.center,
                children: cells
                    .map((c) => SizedBox(
                          width: 86,
                          child: Column(
                            children: [
                              Text(
                                c.$1,
                                style: AppTypography.metricSub,
                              ),
                              AppSpacing.gapH2,
                              Text(
                                c.$2,
                                textAlign: TextAlign.center,
                                style: AppTypography.metricLabel,
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ],
          ),
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

    return Semantics(
      label: '심박수 시계열 차트: 평균 ${run.avgHr?.round() ?? '-'}bpm, 최고 ${run.maxHr?.round() ?? '-'}bpm',
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

  Widget _hrZones(RunSession run) {
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
        padding: AppSpacing.cardPadding,
        child: Column(
          children: [
            Row(
              children: const [
                SizedBox(
                    width: 30,
                    child: Text('세트', style: AppTypography.metricLabel)),
                SizedBox(
                    width: 64,
                    child: Text('종류', style: AppTypography.metricLabel)),
                Expanded(
                    child: Text('시간',
                        textAlign: TextAlign.end,
                        style: AppTypography.metricLabel)),
                Expanded(
                    child: Text('거리(km)',
                        textAlign: TextAlign.end,
                        style: AppTypography.metricLabel)),
                Expanded(
                    child: Text('페이스(/km)',
                        textAlign: TextAlign.end,
                        style: AppTypography.metricLabel)),
              ],
            ),
            const Divider(height: AppSpacing.s16, color: AppColors.borderSubtle),
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
                      child: Text(
                        label,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fmtDuration(seg.durationSec),
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (seg.distanceM / 1000).toStringAsFixed(2),
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        seg.paceSecPerKm > 0
                            ? fmtPace(seg.paceSecPerKm)
                            : '—',
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
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

    String strideLabel = '걸음 데이터 미수신';
    if (run.steps != null && stride == null) {
      strideLabel = '걸음 샘플 불완전 (${run.steps}보)';
    } else if (stride != null) {
      if (stride < 80) {
        strideLabel = '짧은 보폭 (쇼트 피치)';
      } else if (stride <= 115) {
        strideLabel = '효율적인 안정적 보폭';
      } else if (stride <= 145) {
        strideLabel = '넓은 보폭 (롱 스트라이드)';
      } else {
        strideLabel = '고속 질주 보폭';
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
        driftColor = AppColors.warning;
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
        padding: AppSpacing.cardPaddingLarge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: AppSpacing.all14,
                    decoration: BoxDecoration(
                      color: AppColors.cardSubtle,
                      borderRadius: AppRadius.br12,
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('평균 보폭 (Stride)',
                            style: AppTypography.metricLabel),
                        AppSpacing.gapH6,
                        Text(
                          stride != null ? '${stride.round()} cm' : '—',
                          style: AppTypography.metric,
                        ),
                        AppSpacing.gapH4,
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
                AppSpacing.gapW12,
                Expanded(
                  child: Container(
                    padding: AppSpacing.all14,
                    decoration: BoxDecoration(
                      color: AppColors.cardSubtle,
                      borderRadius: AppRadius.br12,
                      border: Border.all(color: AppColors.borderFaint),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('심박 드리프트 (피로도)',
                            style: AppTypography.metricLabel),
                        AppSpacing.gapH6,
                        Text(
                          drift != null
                              ? '${drift >= 0 ? '+' : ''}${drift.toStringAsFixed(1)}%'
                              : '—',
                          style: AppTypography.metric.copyWith(color: driftColor),
                        ),
                        AppSpacing.gapH4,
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
              AppSpacing.gapH16,
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('훈련 성격 분석', style: AppTypography.metricLabel),
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
              AppSpacing.gapH8,
              ClipRRect(
                borderRadius: AppRadius.br6,
                child: SizedBox(
                  height: 12,
                  child: Row(
                    children: [
                      Expanded(
                        flex: (ratio.aerobicPct * 10).round().clamp(1, 1000),
                        child: Container(color: AppColors.cardioGreen),
                      ),
                      if (ratio.anaerobicPct > 0)
                        Expanded(
                          flex:
                              (ratio.anaerobicPct * 10).round().clamp(1, 1000),
                          child: Container(color: AppColors.warning),
                        ),
                    ],
                  ),
                ),
              ),
            ],
            AppSpacing.gapH16,
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s14,
                vertical: AppSpacing.s12,
              ),
              decoration: BoxDecoration(
                color: AppColors.cardSubtle,
                borderRadius: AppRadius.br12,
                border: Border.all(color: AppColors.borderFaint),
              ),
              child: Row(
                children: [
                  Container(
                    padding: AppSpacing.all8,
                    decoration: BoxDecoration(
                      color: AppColors.neon.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bolt,
                      color: AppColors.neon,
                      size: AppIconSizes.standard,
                    ),
                  ),
                  AppSpacing.gapW12,
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
                            AppSpacing.gapW8,
                            Text(
                              '($loadLabel)',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.gapH2,
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
      fontWeight: FontWeight.w700,
    );
    const rowStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    );

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
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
            const Divider(color: AppColors.borderSubtle, height: AppSpacing.s16),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        fmtDuration(lap.durationSec),
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${lap.distanceKm.toStringAsFixed(2)} km',
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lap.paceSecPerKm > 0
                            ? fmtPace(lap.paceSecPerKm)
                            : '—',
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lap.avgHr != null
                            ? '${lap.avgHr!.round()} bpm'
                            : '—',
                        textAlign: TextAlign.end,
                        style: rowStyle,
                      ),
                    ),
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
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
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
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: AppIconSizes.sm,
                  color: AppColors.neon,
                ),
                AppSpacing.gapW6,
                const Text(
                  'AI 러닝 요약',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: AppIconSizes.sm,
                    height: AppIconSizes.sm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _generate,
                    child: Text(_summary == null ? '생성' : '다시 생성'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              )
            else if (_summary != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s10),
                child: Text(
                  _summary!,
                  style: AppTypography.bodyMedium,
                ),
              )
            else if (!_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.s6),
                child: Text(
                  '버튼을 눌러 이 러닝에 대한 AI 코멘트를 받아보세요',
                  style: AppTypography.metricLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
