import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../theme.dart';

/// 러닝 세부 지표 그리드 (칼로리, 심박수, 케이던스, 보폭, 상승고도 등)
class RunDetailMetricsGrid extends StatelessWidget {
  final RunSession run;

  const RunDetailMetricsGrid({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
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

    return Wrap(
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
    );
  }
}
