import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../theme.dart';

/// 워치 랩 기록 테이블 카드
class RunDetailLapsTableCard extends StatelessWidget {
  final RunSession run;

  const RunDetailLapsTableCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    if (run.laps.isEmpty) {
      return const SizedBox.shrink();
    }

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

/// 삼성헬스 인터벌 화면과 같은 구성: 세트 / 종류 / 시간 / 거리 / 페이스 카드
class RunDetailSegmentsCard extends StatelessWidget {
  final RunSession run;

  const RunDetailSegmentsCard({super.key, required this.run});

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

  @override
  Widget build(BuildContext context) {
    if (run.segments.isEmpty) {
      return const SizedBox.shrink();
    }

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
}
