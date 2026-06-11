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
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [level.color, level.colorDark],
                ),
                boxShadow: [
                  BoxShadow(
                      color: level.color.withValues(alpha: 0.35),
                      blurRadius: 14),
                ],
              ),
              child: const Icon(Icons.directions_run,
                  color: Colors.black87, size: 30),
            ),
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
                  Text(
                    next == null
                        ? '최고 레벨 달성!'
                        : '${next.name} 레벨까지 ${(next.minKm - totalKm).toStringAsFixed(1)} km',
                    style: kMetricLabelStyle,
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
