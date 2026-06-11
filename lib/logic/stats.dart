import '../models/run_session.dart';

/// 주간/누적 통계 산출 (PRD 4.2). 주 시작은 월요일.
class StatsSummary {
  final double weekKm;
  final int weekRuns;
  final int weekSec;
  final double totalKm;
  final int totalRuns;
  final int totalSec;
  final int currentStreakWeeks;
  final double longestRunKm;
  final int? best1kPaceSec;
  final int? best5kPaceSec;
  final double maxWeekKm;

  const StatsSummary({
    required this.weekKm,
    required this.weekRuns,
    required this.weekSec,
    required this.totalKm,
    required this.totalRuns,
    required this.totalSec,
    required this.currentStreakWeeks,
    required this.longestRunKm,
    required this.best1kPaceSec,
    required this.best5kPaceSec,
    required this.maxWeekKm,
  });

  static DateTime weekStart(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    return day.subtract(Duration(days: day.weekday - 1));
  }

  factory StatsSummary.fromRuns(List<RunSession> runs, {DateTime? now}) {
    now ??= DateTime.now();
    final thisWeek = weekStart(now);

    double weekKm = 0, totalKm = 0, longestRunKm = 0;
    int weekRuns = 0, weekSec = 0, totalSec = 0;
    int? best1k, best5k;
    final weeklyKm = <DateTime, double>{};
    final weeklyCount = <DateTime, int>{};

    for (final r in runs) {
      totalKm += r.distanceKm;
      totalSec += r.durationSec;
      if (r.distanceKm > longestRunKm) longestRunKm = r.distanceKm;

      final w = weekStart(r.startTime);
      weeklyKm[w] = (weeklyKm[w] ?? 0) + r.distanceKm;
      weeklyCount[w] = (weeklyCount[w] ?? 0) + 1;

      if (w == thisWeek) {
        weekKm += r.distanceKm;
        weekRuns++;
        weekSec += r.durationSec;
      }

      // PB: 1km 최고 페이스는 스플릿에서, 5km는 5km 이상 세션의 평균 페이스에서
      for (final s in r.splits) {
        if (s.km == s.km.roundToDouble() && s.paceSecPerKm > 0) {
          if (best1k == null || s.paceSecPerKm < best1k) {
            best1k = s.paceSecPerKm;
          }
        }
      }
      if (r.distanceKm >= 5 && r.avgPaceSecPerKm > 0) {
        if (best5k == null || r.avgPaceSecPerKm < best5k) {
          best5k = r.avgPaceSecPerKm;
        }
      }
    }

    // 스트릭: 이번 주 포함 연속으로 주 3회 이상 달린 주 수
    // (이번 주는 아직 진행 중이므로 3회 미만이어도 스트릭을 끊지 않음)
    int streak = 0;
    var cursor = thisWeek;
    if ((weeklyCount[cursor] ?? 0) >= 3) streak++;
    cursor = cursor.subtract(const Duration(days: 7));
    while ((weeklyCount[cursor] ?? 0) >= 3) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 7));
    }

    final maxWeekKm = weeklyKm.values.isEmpty
        ? 0.0
        : weeklyKm.values.reduce((a, b) => a > b ? a : b);

    return StatsSummary(
      weekKm: weekKm,
      weekRuns: weekRuns,
      weekSec: weekSec,
      totalKm: totalKm,
      totalRuns: runs.length,
      totalSec: totalSec,
      currentStreakWeeks: streak,
      longestRunKm: longestRunKm,
      best1kPaceSec: best1k,
      best5kPaceSec: best5k,
      maxWeekKm: maxWeekKm,
    );
  }
}

/// 심박존 분포 (Z1~Z5). [maxHr] 기준 비율 구간.
/// Z1 <60%, Z2 60~70%, Z3 70~80%, Z4 80~90%, Z5 90%+
List<double> hrZoneDistribution(List<HrSample> samples, {double maxHr = 190}) {
  final zones = List<double>.filled(5, 0);
  if (samples.isEmpty) return zones;
  for (final s in samples) {
    final pct = s.bpm / maxHr;
    if (pct < 0.6) {
      zones[0]++;
    } else if (pct < 0.7) {
      zones[1]++;
    } else if (pct < 0.8) {
      zones[2]++;
    } else if (pct < 0.9) {
      zones[3]++;
    } else {
      zones[4]++;
    }
  }
  final total = samples.length.toDouble();
  return zones.map((z) => z / total).toList();
}

String fmtDuration(int sec) {
  final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

String fmtPace(int secPerKm) {
  if (secPerKm <= 0) return "-'--\"";
  final m = secPerKm ~/ 60, s = secPerKm % 60;
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
