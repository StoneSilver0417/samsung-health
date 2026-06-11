import '../data/run_repository.dart';
import '../models/achievement.dart';
import '../models/run_session.dart';
import 'stats.dart';

/// 동기화 시마다 로컬에서 업적 조건을 평가한다 (PRD 4.3 — 서버 로직 없음).
class AchievementEngine {
  final RunRepository repo;

  AchievementEngine(this.repo);

  /// 전체 기록 기준으로 미획득 업적을 평가하고, 새로 획득한 배지를 반환·저장한다.
  Future<List<BadgeDef>> evaluate(List<RunSession> allRuns) async {
    if (allRuns.isEmpty) return const [];

    final earned = repo.getEarnedBadges().map((e) => e.badgeId).toSet();
    final stats = StatsSummary.fromRuns(allRuns);
    final newlyEarned = <EarnedBadge>[];
    final now = DateTime.now();

    void earn(String badgeId, {String? runId}) {
      if (earned.contains(badgeId)) return;
      newlyEarned
          .add(EarnedBadge(badgeId: badgeId, earnedAt: now, runId: runId));
      earned.add(badgeId);
    }

    // ── 거리 (단일 세션)
    earn('first_run', runId: allRuns.last.id);
    for (final r in allRuns) {
      if (r.distanceKm >= 5) earn('first_5k', runId: r.id);
      if (r.distanceKm >= 10) earn('first_10k', runId: r.id);
    }

    // ── 누적 거리
    if (stats.totalKm >= 50) earn('total_50k');
    if (stats.totalKm >= 100) earn('total_100k');
    if (stats.totalKm >= 250) earn('total_250k');
    if (stats.totalKm >= 500) earn('total_500k');

    // ── 시간 (단일 세션)
    for (final r in allRuns) {
      if (r.durationSec >= 10 * 60) earn('run_10min', runId: r.id);
      if (r.durationSec >= 20 * 60) earn('run_20min', runId: r.id);
      if (r.durationSec >= 30 * 60) earn('run_30min', runId: r.id);
      if (r.durationSec >= 60 * 60) earn('run_60min', runId: r.id);
    }

    // ── 꾸준함
    final weekly = weeklyCounts(allRuns);
    if (weekly.values.any((c) => c >= 3)) earn('week_3runs');
    final maxStreak = maxConsecutiveWeeks(weekly);
    if (maxStreak >= 2) earn('streak_2w');
    if (maxStreak >= 4) earn('streak_4w');

    final monthly = <String, int>{};
    for (final r in allRuns) {
      final key = '${r.startTime.year}-${r.startTime.month}';
      monthly[key] = (monthly[key] ?? 0) + 1;
    }
    if (monthly.values.any((c) => c >= 10)) earn('month_10runs');

    // ── 스페셜: 야간 러너 (21시~새벽 4시 시작 10회)
    if (nightRunCount(allRuns) >= 10) earn('night_owl');

    if (newlyEarned.isNotEmpty) {
      await repo.saveEarnedBadges(newlyEarned);
    }
    return newlyEarned
        .map((e) => kBadges.firstWhere((b) => b.id == e.badgeId))
        .toList();
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
      case 'total_50k':
        return '${stats.totalKm.toStringAsFixed(1)} / 50 km';
      case 'total_100k':
        return '${stats.totalKm.toStringAsFixed(1)} / 100 km';
      case 'total_250k':
        return '${stats.totalKm.toStringAsFixed(1)} / 250 km';
      case 'total_500k':
        return '${stats.totalKm.toStringAsFixed(1)} / 500 km';
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
      default:
        return null;
    }
  }
}
