import '../data/run_repository.dart';
import '../models/achievement.dart';
import '../models/run_session.dart';
import 'stats.dart';

/// 동기화 시마다 로컬에서 업적 조건을 평가한다 (PRD 4.3 — 서버 로직 없음).
class AchievementEngine {
  final RunRepository repo;

  AchievementEngine(this.repo);

  /// 전체 기록 기준으로 미획득 업적을 평가하고, 새로 획득한 배지를 반환·저장한다.
  /// allRuns는 오래된 순(오름차순)으로 정렬되어 있어야 한다.
  Future<List<BadgeDef>> evaluate(List<RunSession> allRuns) async {
    if (allRuns.isEmpty) return const [];

    final earned = repo.getEarnedBadges().map((e) => e.badgeId).toSet();
    final newlyEarned = <EarnedBadge>[];
    final now = DateTime.now();

    void earn(String badgeId, {String? runId, DateTime? earnedAt}) {
      if (earned.contains(badgeId)) return;
      newlyEarned.add(EarnedBadge(
          badgeId: badgeId, earnedAt: earnedAt ?? now, runId: runId));
      earned.add(badgeId);
    }

    // ── 거리 (단일 세션) — allRuns[0]이 가장 오래된 기록
    earn('first_run',
        runId: allRuns.first.id, earnedAt: allRuns.first.startTime);
    for (final r in allRuns) {
      if (r.distanceKm >= 5) earn('first_5k', runId: r.id, earnedAt: r.startTime);
      if (r.distanceKm >= 10) earn('first_10k', runId: r.id, earnedAt: r.startTime);
      if (r.distanceKm >= 21.1) earn('first_half', runId: r.id, earnedAt: r.startTime);
    }

    // ── 누적 거리: 임계값을 처음 넘은 러닝 날짜 사용
    double cumKm = 0;
    for (final r in allRuns) {
      cumKm += r.distanceKm;
      if (cumKm >= 50) earn('total_50k', earnedAt: r.startTime);
      if (cumKm >= 100) earn('total_100k', earnedAt: r.startTime);
      if (cumKm >= 250) earn('total_250k', earnedAt: r.startTime);
      if (cumKm >= 500) earn('total_500k', earnedAt: r.startTime);
      if (cumKm >= 1000) earn('total_1000k', earnedAt: r.startTime);
    }

    // ── 러닝 횟수: n번째 러닝 날짜 사용 (0-indexed)
    if (allRuns.length >= 25) earn('runs_25', earnedAt: allRuns[24].startTime);
    if (allRuns.length >= 50) earn('runs_50', earnedAt: allRuns[49].startTime);
    if (allRuns.length >= 100) earn('runs_100', earnedAt: allRuns[99].startTime);

    // ── 시간 (단일 세션)
    for (final r in allRuns) {
      if (r.durationSec >= 10 * 60) earn('run_10min', runId: r.id, earnedAt: r.startTime);
      if (r.durationSec >= 20 * 60) earn('run_20min', runId: r.id, earnedAt: r.startTime);
      if (r.durationSec >= 30 * 60) earn('run_30min', runId: r.id, earnedAt: r.startTime);
      if (r.durationSec >= 60 * 60) earn('run_60min', runId: r.id, earnedAt: r.startTime);
    }

    // ── 꾸준함
    final weekly = weeklyCounts(allRuns);

    // week_3runs: 처음으로 주3회를 달성한 주의 3번째 러닝 날짜
    final qualifiedWeeks = weekly.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toList()
      ..sort();
    if (qualifiedWeeks.isNotEmpty) {
      final wStart = qualifiedWeeks.first;
      final wEnd = wStart.add(const Duration(days: 7));
      final runsInWeek = allRuns
          .where((r) =>
              !r.startTime.isBefore(wStart) && r.startTime.isBefore(wEnd))
          .toList();
      if (runsInWeek.length >= 3) {
        earn('week_3runs', earnedAt: runsInWeek[2].startTime);
      }
    }

    // streak badges: 목표 연속 주수를 처음 달성한 시점의 마지막 러닝 날짜
    final maxStreak = maxConsecutiveWeeks(weekly);
    if (maxStreak >= 2) {
      earn('streak_2w',
          earnedAt: _streakEndDate(weekly, allRuns, 2));
    }
    if (maxStreak >= 4) {
      earn('streak_4w',
          earnedAt: _streakEndDate(weekly, allRuns, 4));
    }
    if (maxStreak >= 8) {
      earn('streak_8w',
          earnedAt: _streakEndDate(weekly, allRuns, 8));
    }

    // month_10runs: 월 10회를 최초 달성한 달의 10번째 러닝 날짜
    final monthly = <String, List<RunSession>>{};
    for (final r in allRuns) {
      final key = '${r.startTime.year}-${r.startTime.month.toString().padLeft(2, '0')}';
      monthly.putIfAbsent(key, () => []).add(r);
    }
    final sortedMonths = monthly.keys.toList()..sort();
    for (final key in sortedMonths) {
      final runs = monthly[key]!;
      if (runs.length >= 10) {
        earn('month_10runs', earnedAt: runs[9].startTime);
        break;
      }
    }

    // ── 스페셜: n번째 조건 충족 러닝 날짜
    final nightRuns = allRuns
        .where((r) => r.startTime.hour >= 21 || r.startTime.hour < 4)
        .toList();
    if (nightRuns.length >= 10) {
      earn('night_owl', earnedAt: nightRuns[9].startTime);
    }

    final earlyRuns = allRuns
        .where((r) => r.startTime.hour >= 5 && r.startTime.hour < 8)
        .toList();
    if (earlyRuns.length >= 5) {
      earn('early_bird', earnedAt: earlyRuns[4].startTime);
    }

    final weekendRuns = allRuns
        .where((r) =>
            r.startTime.weekday == DateTime.saturday ||
            r.startTime.weekday == DateTime.sunday)
        .toList();
    if (weekendRuns.length >= 10) {
      earn('weekend_warrior', earnedAt: weekendRuns[9].startTime);
    }

    for (final r in allRuns) {
      // 평균 페이스 6분/km(360초) 이하 — 1km 미만 잡음 세션 제외
      if (r.distanceKm >= 1 &&
          r.avgPaceSecPerKm > 0 &&
          r.avgPaceSecPerKm <= 360) {
        earn('speed_sub6', runId: r.id, earnedAt: r.startTime);
      }
    }

    if (newlyEarned.isNotEmpty) {
      await repo.saveEarnedBadges(newlyEarned);
    }
    return newlyEarned
        .map((e) => kBadges.firstWhere((b) => b.id == e.badgeId))
        .toList();
  }

  /// 목표 연속 주수(targetLength)를 처음 달성한 마지막 주의 최종 러닝 날짜 반환.
  static DateTime? _streakEndDate(
      Map<DateTime, int> weekly, List<RunSession> allRuns, int targetLength) {
    final qualified = weekly.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toList()
      ..sort();
    int current = 0;
    DateTime? prev;
    for (final w in qualified) {
      current =
          (prev != null && w.difference(prev).inDays == 7) ? current + 1 : 1;
      if (current >= targetLength) {
        final wEnd = w.add(const Duration(days: 7));
        final runsInWeek = allRuns
            .where((r) =>
                !r.startTime.isBefore(w) && r.startTime.isBefore(wEnd))
            .toList();
        return runsInWeek.isNotEmpty ? runsInWeek.last.startTime : w;
      }
      prev = w;
    }
    return null;
  }

  static Map<DateTime, int> weeklyCounts(List<RunSession> runs) {
    final weekly = <DateTime, int>{};
    for (final r in runs) {
      final w = StatsSummary.weekStart(r.startTime);
      weekly[w] = (weekly[w] ?? 0) + 1;
    }
    return weekly;
  }

  /// 주 3회 이상을 채운 주들의 최장 연속 길이
  static int maxConsecutiveWeeks(Map<DateTime, int> weekly) {
    final qualified = weekly.entries
        .where((e) => e.value >= 3)
        .map((e) => e.key)
        .toList()
      ..sort();
    int best = 0, current = 0;
    DateTime? prev;
    for (final w in qualified) {
      current = (prev != null && w.difference(prev).inDays == 7)
          ? current + 1
          : 1;
      if (current > best) best = current;
      prev = w;
    }
    return best;
  }

  static int nightRunCount(List<RunSession> runs) => runs
      .where((r) => r.startTime.hour >= 21 || r.startTime.hour < 4)
      .length;

  static int earlyBirdCount(List<RunSession> runs) => runs
      .where((r) => r.startTime.hour >= 5 && r.startTime.hour < 8)
      .length;

  static int weekendCount(List<RunSession> runs) => runs
      .where((r) =>
          r.startTime.weekday == DateTime.saturday ||
          r.startTime.weekday == DateTime.sunday)
      .length;

  /// 미획득 배지의 진행률 텍스트 (배지 보관함 표시용)
  static String? progressText(String badgeId, List<RunSession> runs) {
    if (runs.isEmpty) return null;
    final stats = StatsSummary.fromRuns(runs);
    final maxSec =
        runs.map((r) => r.durationSec).reduce((a, b) => a > b ? a : b);
    final weekly = weeklyCounts(runs);
    final streak = maxConsecutiveWeeks(weekly);

    switch (badgeId) {
      case 'first_5k':
        return '최장 ${stats.longestRunKm.toStringAsFixed(1)} / 5 km';
      case 'first_10k':
        return '최장 ${stats.longestRunKm.toStringAsFixed(1)} / 10 km';
      case 'first_half':
        return '최장 ${stats.longestRunKm.toStringAsFixed(1)} / 21.1 km';
      case 'total_50k':
        return '${stats.totalKm.toStringAsFixed(1)} / 50 km';
      case 'total_100k':
        return '${stats.totalKm.toStringAsFixed(1)} / 100 km';
      case 'total_250k':
        return '${stats.totalKm.toStringAsFixed(1)} / 250 km';
      case 'total_500k':
        return '${stats.totalKm.toStringAsFixed(1)} / 500 km';
      case 'total_1000k':
        return '${stats.totalKm.toStringAsFixed(1)} / 1000 km';
      case 'runs_25':
        return '${runs.length} / 25회';
      case 'runs_50':
        return '${runs.length} / 50회';
      case 'runs_100':
        return '${runs.length} / 100회';
      case 'run_10min':
        return '최장 ${fmtDuration(maxSec)} / 10:00';
      case 'run_20min':
        return '최장 ${fmtDuration(maxSec)} / 20:00';
      case 'run_30min':
        return '최장 ${fmtDuration(maxSec)} / 30:00';
      case 'run_60min':
        return '최장 ${fmtDuration(maxSec)} / 1:00:00';
      case 'streak_2w':
        return '$streak / 2주 연속';
      case 'streak_4w':
        return '$streak / 4주 연속';
      case 'streak_8w':
        return '$streak / 8주 연속';
      case 'month_10runs':
        final monthly = <String, int>{};
        for (final r in runs) {
          final key = '${r.startTime.year}-${r.startTime.month}';
          monthly[key] = (monthly[key] ?? 0) + 1;
        }
        final maxMonth =
            monthly.values.reduce((a, b) => a > b ? a : b);
        return '최다 $maxMonth / 10회';
      case 'night_owl':
        return '${nightRunCount(runs)} / 10회';
      case 'early_bird':
        return '${earlyBirdCount(runs)} / 5회';
      case 'weekend_warrior':
        return '${weekendCount(runs)} / 10회';
      case 'speed_sub6':
        final best = stats.best5kPaceSec ?? stats.best1kPaceSec;
        return best != null ? '최고 ${fmtPace(best)} / 6\'00"' : '6\'00" 목표';
      default:
        return null;
    }
  }
}
