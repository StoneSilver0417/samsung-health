import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../theme.dart';
import 'run_detail_metrics_grid.dart';

/// 러닝 상세 상단 핵심 요약 히어로 헤더 카드 (거리, 시간, 페이스 및 주요 지표)
class RunDetailHeroHeader extends StatelessWidget {
  final RunSession run;

  const RunDetailHeroHeader({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label:
          '러닝 요약: 거리 ${run.distanceKm.toStringAsFixed(2)}km, 시간 ${fmtDuration(run.durationSec)}, 평균 페이스 ${fmtPace(run.avgPaceSecPerKm)}',
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
              RunDetailMetricsGrid(run: run),
            ],
          ),
        ),
      ),
    );
  }
}
