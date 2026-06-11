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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_run,
                      color: AppColors.neon, size: 18),
                  const SizedBox(width: 6),
                  Text(date, style: kMetricLabelStyle),
                  const Spacer(),
                  if (run.sourceName == 'demo')
                    const Text('DEMO',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 10)),
                ],
              ),
              const SizedBox(height: 10),
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
    );
  }

  Widget _metric(String value, String label) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                )),
            Text(label, style: kMetricLabelStyle),
          ],
        ),
      );
}
