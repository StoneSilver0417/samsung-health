import 'package:flutter/material.dart';

import '../../logic/levels.dart';
import '../theme.dart';

/// NRC 스타일 러너 레벨 카드 — 누적 거리 기준 레벨 + 다음 레벨까지 진행률
class LevelCard extends StatelessWidget {
  final double totalKm;

  const LevelCard({super.key, required this.totalKm});

  @override
  Widget build(BuildContext context) {
    final level = levelFor(totalKm);
    final next = nextLevelFor(totalKm);
    final progress = next == null
        ? 1.0
        : ((totalKm - level.minKm) / (next.minKm - level.minKm))
            .clamp(0.0, 1.0);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showAllLevels(context, level),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _levelBadge(level, 58, 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${level.name} 레벨',
                            style: TextStyle(
                                color: level.color,
                                fontSize: 16,
                                fontWeight: FontWeight.w900)),
                        const Spacer(),
                        Text('${totalKm.toStringAsFixed(1)} km',
                            style: kMetricLabelStyle),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        color: level.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            next == null
                                ? '최고 레벨 달성!'
                                : '${next.name} 레벨까지 ${(next.minKm - totalKm).toStringAsFixed(1)} km',
                            style: kMetricLabelStyle,
                          ),
                        ),
                        const Text('전체 등급 보기',
                            style: TextStyle(
                                color: AppColors.neon,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const Icon(Icons.chevron_right,
                            size: 16, color: AppColors.neon),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _levelBadge(RunnerLevel level, double size, double icon) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [level.color, level.colorDark],
          ),
          boxShadow: [
            BoxShadow(
                color: level.color.withValues(alpha: 0.35), blurRadius: 14),
          ],
        ),
        child: Icon(Icons.directions_run,
            color: Colors.black87, size: icon),
      );

  void _showAllLevels(BuildContext context, RunnerLevel current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ListView(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, 20 + MediaQuery.viewPaddingOf(ctx).bottom),
        shrinkWrap: true,
        children: [
          const Text('러너 레벨 등급',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('현재 ${totalKm.toStringAsFixed(1)} km',
              style: kMetricLabelStyle),
          const SizedBox(height: 16),
          ...kLevels.map((l) {
            final isCurrent = l.name == current.name;
            final achieved = totalKm >= l.minKm;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent
                    ? l.color.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCurrent
                      ? l.color.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                children: [
                  Opacity(
                    opacity: achieved ? 1.0 : 0.35,
                    child: _levelBadge(l, 40, 21),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('${l.name} 레벨',
                                style: TextStyle(
                                    color: achieved
                                        ? l.color
                                        : AppColors.textSecondary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800)),
                            if (isCurrent) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: l.color,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('현재',
                                    style: TextStyle(
                                        color: Colors.black,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900)),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          l.minKm == 0
                              ? '시작 등급'
                              : '${l.minKm.toStringAsFixed(0)} km 누적',
                          style: kMetricLabelStyle,
                        ),
                      ],
                    ),
                  ),
                  if (achieved && !isCurrent)
                    const Icon(Icons.check_circle,
                        size: 18, color: AppColors.neon),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
