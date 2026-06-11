import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 주간 목표 대비 진행 링 (PRD 4.4 — 액티비티 링 스타일).
/// 바깥 링: 거리 목표, 안쪽 링: 횟수 목표.
class WeeklyRing extends StatelessWidget {
  final double weekKm;
  final int weekRuns;
  final double goalKm;
  final int goalRuns;

  const WeeklyRing({
    super.key,
    required this.weekKm,
    required this.weekRuns,
    this.goalKm = 15,
    this.goalRuns = 3,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 190,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(190, 190),
            painter: _RingPainter(
              distProgress: (weekKm / goalKm).clamp(0.0, 1.0),
              runsProgress: (weekRuns / goalRuns).clamp(0.0, 1.0),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(weekKm.toStringAsFixed(1), style: kMetricStyle),
              const Text('km 이번 주', style: kMetricLabelStyle),
              const SizedBox(height: 4),
              Text(
                '$weekRuns / $goalRuns 회',
                style: const TextStyle(
                  color: AppColors.neon,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double distProgress;
  final double runsProgress;

  _RingPainter({required this.distProgress, required this.runsProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const startAngle = -pi / 2;

    void drawRing(double radius, double progress, Color color, double width) {
      final bgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color.withValues(alpha: 0.15);
      final fgPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color;
      canvas.drawCircle(center, radius, bgPaint);
      if (progress > 0) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          2 * pi * progress,
          false,
          fgPaint,
        );
      }
    }

    drawRing(size.width / 2 - 7, distProgress, AppColors.neon, 12);
    drawRing(size.width / 2 - 26, runsProgress, AppColors.zoneColors[1], 9);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.distProgress != distProgress || old.runsProgress != runsProgress;
}
