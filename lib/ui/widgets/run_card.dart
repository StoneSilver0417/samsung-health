import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../logic/stats.dart';
import '../../models/run_session.dart';
import '../theme.dart';

class RunCard extends StatelessWidget {
  final RunSession run;
  final VoidCallback? onTap;

  const RunCard({super.key, required this.run, this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('M월 d일 (E) HH:mm', 'ko').format(run.startTime);
    final semanticLabel =
        '$date 러닝 기록: 거리 ${run.distanceKm.toStringAsFixed(2)}km, 시간 ${fmtDuration(run.durationSec)}, 평균 페이스 ${fmtPace(run.avgPaceSecPerKm)}${run.avgHr != null ? ', 평균 심박수 ${run.avgHr!.round()}bpm' : ''}';

    return Semantics(
      label: semanticLabel,
      button: true,
      hint: '탭하여 러닝 상세 분석 화면으로 이동합니다.',
      child: Card(
        child: InkWell(
          borderRadius: const BorderRadius.all(AppRadius.radius16),
          onTap: onTap,
          child: Padding(
            padding: AppSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.directions_run,
                      color: AppColors.neon,
                      size: AppIconSizes.md,
                    ),
                    AppSpacing.gapW6,
                    Text(date, style: AppTypography.metricLabel),
                    const Spacer(),
                    if (run.sourceName == 'demo')
                      const Text(
                        'DEMO',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
                AppSpacing.gapH10,
                Row(
                  children: [
                    _metric('${run.distanceKm.toStringAsFixed(2)} km', '거리'),
                    _metric(fmtDuration(run.durationSec), '시간'),
                    _metric(fmtPace(run.avgPaceSecPerKm), '페이스'),
                    if (run.avgHr != null)
                      _metric('${run.avgHr!.round()}', '심박'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metric(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(label, style: AppTypography.metricLabel),
          ],
        ),
      );
}
