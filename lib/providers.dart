import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/run_repository.dart';
import 'logic/achievement_engine.dart';
import 'logic/stats.dart';
import 'models/achievement.dart';
import 'models/run_session.dart';
import 'services/health_service.dart';

/// main()에서 열린 Hive 저장소로 override됨
final repoProvider = Provider<RunRepository>(
  (ref) => throw UnimplementedError('main()에서 override 필요'),
);

final healthServiceProvider = Provider<HealthService>((ref) => HealthService());

class SyncResult {
  final int addedCount;
  final List<BadgeDef> newBadges;
  final String? error;
  const SyncResult({this.addedCount = 0, this.newBadges = const [], this.error});
}

class RunsNotifier extends AsyncNotifier<List<RunSession>> {
  @override
  Future<List<RunSession>> build() => ref.read(repoProvider).getAll();

  /// Health Connect에서 증분 동기화. 경계 유실 방지를 위해 마지막 동기화 1일 전부터
  /// 다시 읽는다 (UUID dedupe가 중복을 걸러줌).
  Future<SyncResult> sync() async {
    final repo = ref.read(repoProvider);
    final health = ref.read(healthServiceProvider);
    try {
      await health.configure();
      final granted = await health.requestPermissions();
      if (!granted) {
        return const SyncResult(error: 'Health Connect 권한이 거부되었습니다');
      }

      final since =
          repo.lastSyncedAt?.subtract(const Duration(days: 1));
      final fetched = await health.fetchRuns(since: since);
      final added = await repo.upsertAll(fetched);
      await repo.setLastSyncedAt(DateTime.now());

      final all = await repo.getAll();
      final newBadges =
          await AchievementEngine(repo).evaluate(all.reversed.toList());

      state = AsyncData(all);
      return SyncResult(addedCount: added.length, newBadges: newBadges);
    } catch (e) {
      return SyncResult(error: '동기화 실패: $e');
    }
  }

  Future<void> deleteRun(String id) async {
    final repo = ref.read(repoProvider);
    await repo.delete(id);
    state = AsyncData(await repo.getAll());
  }

  /// PC/에뮬레이터 등 Health Connect 없는 환경에서 UI 확인용 (PRD 검증 보조)
  Future<SyncResult> seedDemoData() async {
    final repo = ref.read(repoProvider);
    final added = await repo.upsertAll(_generateDemoRuns());
    final all = await repo.getAll();
    final newBadges =
        await AchievementEngine(repo).evaluate(all.reversed.toList());
    state = AsyncData(all);
    return SyncResult(addedCount: added.length, newBadges: newBadges);
  }

  Future<void> clearAll() async {
    final repo = ref.read(repoProvider);
    await repo.clear();
    state = const AsyncData([]);
  }
}

final runsProvider =
    AsyncNotifierProvider<RunsNotifier, List<RunSession>>(RunsNotifier.new);

final statsProvider = Provider<StatsSummary>((ref) {
  final runs = ref.watch(runsProvider).value ?? const <RunSession>[];
  return StatsSummary.fromRuns(runs);
});

final earnedBadgesProvider = Provider<Map<String, EarnedBadge>>((ref) {
  ref.watch(runsProvider); // 동기화 후 재평가 반영
  final repo = ref.read(repoProvider);
  return {for (final b in repo.getEarnedBadges()) b.badgeId: b};
});

/// 야간 러닝(21~22시, 강변 코스) 패턴의 데모 데이터 (PRD 1.1 배경 반영)
List<RunSession> _generateDemoRuns() {
  final rng = Random(42);
  final runs = <RunSession>[];
  final now = DateTime.now();

  for (int i = 0; i < 10; i++) {
    final daysAgo = (i * 2.2).round() + 1;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysAgo))
        .add(Duration(hours: 21, minutes: rng.nextInt(40)));
    // 최근일수록 거리·페이스 개선 (체력 증진 추세 시각화 확인용)
    final km = 2.5 + (10 - i) * 0.35 + rng.nextDouble() * 0.5;
    final paceSec = 420 + i * 6 + rng.nextInt(20); // 7'00"대에서 점진 개선
    final durationSec = (km * paceSec).round();
    final end = start.add(Duration(seconds: durationSec));

    final hrSeries = <HrSample>[];
    final minutes = durationSec ~/ 60;
    for (int m = 0; m <= minutes; m++) {
      final warmup = (m / 6).clamp(0.0, 1.0);
      hrSeries.add(HrSample(
        time: start.add(Duration(minutes: m)),
        bpm: 115 + warmup * (45 - i * 1.5) + rng.nextInt(8),
      ));
    }

    final splits = <Split>[];
    for (int k = 1; k <= km.floor(); k++) {
      splits.add(Split(
        km: k.toDouble(),
        paceSecPerKm: paceSec + rng.nextInt(24) - 12,
        avgHr: 140 + rng.nextInt(20).toDouble(),
      ));
    }

    runs.add(RunSession(
      id: 'demo-$i',
      startTime: start,
      endTime: end,
      distanceM: km * 1000,
      durationSec: durationSec,
      avgHr: hrSeries.fold<double>(0, (s, h) => s + h.bpm) / hrSeries.length,
      maxHr: hrSeries.map((h) => h.bpm).reduce(max),
      calories: km * 62,
      splits: splits,
      hrSeries: hrSeries,
      sourceName: 'demo',
    ));
  }
  return runs;
}
