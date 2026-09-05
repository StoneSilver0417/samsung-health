import 'package:flutter/material.dart';

import '../../../logic/stats.dart';
import '../../theme.dart';

/// 개인 최고 기록 (PB) 카드
class PbRecordsCard extends StatelessWidget {
  final StatsSummary stats;

  const PbRecordsCard({super.key, required this.stats});

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
          children: [
            _row('최장 거리', '${stats.longestRunKm.toStringAsFixed(2)} km'),
            _row(
              '최고 1km 페이스',
              stats.best1kPaceSec != null ? fmtPace(stats.best1kPaceSec!) : '—',
            ),
            _row(
              '최고 5km+ 평균 페이스',
              stats.best5kPaceSec != null ? fmtPace(stats.best5kPaceSec!) : '—',
            ),
            _row('최다 주간 거리', '${stats.maxWeekKm.toStringAsFixed(1)} km'),
            _row('총 러닝 시간', fmtDuration(stats.totalSec)),
          ],
        ),
      ),
    );
  }
}
