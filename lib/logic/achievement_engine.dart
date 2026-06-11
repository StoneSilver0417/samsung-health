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

    // 첫 러닝
    earn('first_run', runId: allRuns.last.id);

    // 단일 세션 5km
    for (final r in allRuns) {
      if (r.distanceKm >= 5) {
        earn('first_5k', runId: r.id);
        break;
      }
    }

    // 30분 이상 세션
    for (final r in allRuns) {
      if (r.durationSec >= 30 * 60) {
        earn('run_30min', runId: r.id);
        break;
      }
    }

    // 주 3회 (어느 주든 한 번이라도 달성)
    final weekly = <DateTime, int>{};
    for (final r in allRuns) {
      final w = StatsSummary.weekStart(r.startTime);
      weekly[w] = (weekly[w] ?? 0) + 1;
    }
    if (weekly.values.any((c) => c >= 3)) earn('week_3runs');

    // 누적 50km
    if (stats.totalKm >= 50) earn('total_50k');

    if (newlyEarned.isNotEmpty) {
      await repo.saveEarnedBadges(newlyEarned);
    }
    return newlyEarned
        .map((e) => kBadges.firstWhere((b) => b.id == e.badgeId))
        .toList();
  }

  /// 미획득 배지의 진행률 텍스트 (배지 보관함 표시용)
  static String? progressText(String badgeId, List<RunSession> runs) {
    final stats = StatsSummary.fromRuns(runs);
    switch (badgeId) {
      case 'total_50k':
        return '${stats.totalKm.toStringAsFixed(1)} / 50 km';
      case 'first_5k':
        return '최장 ${stats.longestRunKm.toStringAsFixed(1)} / 5 km';
      case 'run_30min':
        final maxSec = runs.isEmpty
            ? 0
            : runs.map((r) => r.durationSec).reduce((a, b) => a > b ? a : b);
        return '최장 ${fmtDuration(maxSec)} / 30:00';
      default:
        return null;
    }
  }
}
