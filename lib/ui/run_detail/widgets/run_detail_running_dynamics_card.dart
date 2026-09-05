import 'package:flutter/material.dart';

import '../../../models/run_session.dart';
import '../../theme.dart';

/// 러닝 역학 (보폭, 심박 드리프트) & 심폐 효율 (유산소 비율, 훈련부하/회복시간) 카드
class RunDetailRunningDynamicsCard extends StatelessWidget {
  final RunSession run;

  const RunDetailRunningDynamicsCard({super.key, required this.run});

  @override
  Widget build(BuildContext context) {
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
                        const Text(
                          '평균 보폭 (Stride)',
                          style: AppTypography.metricLabel,
                        ),
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
                        const Text(
                          '심박 드리프트 (피로도)',
                          style: AppTypography.metricLabel,
                        ),
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
                          flex: (ratio.anaerobicPct * 10).round().clamp(1, 1000),
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
}
