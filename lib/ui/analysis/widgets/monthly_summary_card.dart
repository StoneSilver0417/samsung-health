import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../theme.dart';

/// 이번 달 러닝 요약 카드
class MonthlySummaryCard extends StatelessWidget {
  final MonthlyStats stats;

  const MonthlySummaryCard({super.key, required this.stats});

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s6),
        child: Row(
          children: [
            Text(label, style: AppTypography.metricLabel),
            const Spacer(),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  stats.thisMonthKm.toStringAsFixed(1),
                  style: AppTypography.largeMetric.copyWith(
                    color: AppColors.neon,
                  ),
                ),
                AppSpacing.gapW6,
                const Padding(
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text('km', style: AppTypography.metricLabel),
                ),
              ],
            ),
            AppSpacing.gapH12,
            _row('러닝 횟수', '${stats.thisMonthRuns}회'),
            _row('총 시간', fmtDuration(stats.thisMonthSec)),
            _row(
              '평균 페이스',
              stats.thisMonthAvgPaceSec == null
                  ? '—'
                  : '${fmtPace(stats.thisMonthAvgPaceSec!)}/km',
            ),
            _row(
              '최장 거리',
              '${stats.thisMonthLongestKm.toStringAsFixed(2)} km',
            ),
          ],
        ),
      ),
    );
  }
}

/// 지난달 대비 러닝 변화 비교 카드
class MonthCompareCard extends StatelessWidget {
  final MonthlyStats stats;

  const MonthCompareCard({super.key, required this.stats});

  Widget _row(
    String label,
    String value,
    String deltaText,
    bool? improved,
  ) {
    final deltaColor = improved == null
        ? AppColors.textSecondary
        : improved
            ? AppColors.neon
            : AppColors.danger;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppTypography.metricLabel)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          AppSpacing.gapW10,
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (improved != null)
                Icon(
                  improved ? Icons.arrow_upward : Icons.arrow_downward,
                  size: AppIconSizes.xs,
                  color: deltaColor,
                ),
              Text(
                deltaText,
                style: TextStyle(
                  color: deltaColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (stats.lastMonthRuns == 0) {
      return const Card(
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Text(
            '지난달 러닝 기록이 없어 비교할 수 없습니다',
            style: AppTypography.metricLabel,
          ),
        ),
      );
    }

    final kmDelta = stats.thisMonthKm - stats.lastMonthKm;
    final runDelta = stats.thisMonthRuns - stats.lastMonthRuns;
    final secDelta = stats.thisMonthSec - stats.lastMonthSec;
    final currentPace = stats.thisMonthAvgPaceSec;
    final lastPace = stats.lastMonthAvgPaceSec;

    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          children: [
            _row(
              '거리',
              '${stats.thisMonthKm.toStringAsFixed(1)} km',
              '${kmDelta.abs().toStringAsFixed(1)} km',
              kmDelta >= 0,
            ),
            _row(
              '횟수',
              '${stats.thisMonthRuns}회',
              '${runDelta.abs()}회',
              runDelta >= 0,
            ),
            _row(
              '시간',
              fmtDuration(stats.thisMonthSec),
              fmtDuration(secDelta.abs()),
              secDelta >= 0,
            ),
            if (currentPace != null && lastPace != null)
              _row(
                '평균 페이스',
                '${fmtPace(currentPace)}/km',
                '${fmtDuration((currentPace - lastPace).abs())}/km',
                currentPace <= lastPace,
              )
            else
              _row(
                '평균 페이스',
                currentPace == null ? '—' : '${fmtPace(currentPace)}/km',
                '비교 불가',
                null,
              ),
          ],
        ),
      ),
    );
  }
}
