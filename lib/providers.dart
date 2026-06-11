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

      // 고도·VO2max 추가 권한 (거부해도 기본 동기화는 진행)
      await health.requestExtraPermissions();

      final since =
          repo.lastSyncedAt?.subtract(const Duration(days: 1));
      final fetched = await health.fetchRuns(since: since);
      final added = await repo.upsertAll(fetched);
      await repo.setLastSyncedAt(DateTime.now());

      // VO2max 추세 (최근 90일)
      final vo2 = await health.fetchVo2Series(
          DateTime.now().subtract(const Duration(days: 90)), DateTime.now());
      if (vo2.isNotEmpty) await repo.saveVo2Series(vo2);

      final all = await repo.getAll();
      final newBadges =
          await AchievementEngine(repo).evaluate(all.reversed.toList());

      state = AsyncData(all);
      return SyncResult(addedCount: added.length, newBadges: newBadges);
    } catch (e) {
      return SyncResult(error: '동기화 실패: $e');
    }
  }

  /// 과거 기록 가져오기: [from]부터의 러닝 후보 조회 (저장하지 않음).
  /// 30일보다 먼 과거는 히스토리 권한을 추가로 요청한다.
  Future<List<RunSession>> fetchCandidates(DateTime from) async {
    final health = ref.read(healthServiceProvider);
    await health.configure();
    final granted = await health.requestPermissions();
    if (!granted) {
      throw Exception('Health Connect 권한이 거부되었습니다');
    }
    final needsHistory =
        DateTime.now().difference(from) > const Duration(days: 29);
    if (needsHistory) {
      final historyOk = await health.requestHistoryPermission();
      if (!historyOk) {
        throw Exception('과거 데이터 권한이 거부되어 최근 30일만 조회됩니다');
      }
    }
    final runs = await health.fetchRuns(since: from);
    runs.sort((a, b) => b.startTime.compareTo(a.startTime));
    return runs;
  }

  /// 선택된 과거 기록 저장 + 업적 재평가
  Future<SyncResult> importRuns(List<RunSession> selected) async {
    final repo = ref.read(repoProvider);
    final added = await repo.upsertAll(selected);
    final all = await repo.getAll();
    final newBadges =
        await AchievementEngine(repo).evaluate(all.reversed.toList());
    state = AsyncData(all);
    return SyncResult(addedCount: added.length, newBadges: newBadges);
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

final vo2SeriesProvider = Provider<List<(DateTime, double)>>((ref) {
  ref.watch(runsProvider); // 동기화 후 갱신
  return ref.read(repoProvider).getVo2Series();
});

final earnedBadgesProvider = Provider<Map<String, EarnedBadge>>((ref) {
  ref.watch(runsProvider); // 동기화 후 재평가 반영
  final repo = ref.read(repoProvider);
  return {for (final b in repo.getEarnedBadges()) b.badgeId: b};
});

/// 23일 프로그램 스타일 인터벌: 준비 3분 → (운동 6분 + 회복 1분)× → 마무리
List<RunSegment> _demoSegments(
    DateTime start, int durationSec, double totalM, Random rng) {
  final segments = <RunSegment>[];
  const warmupSec = 180, runSec = 360, restSec = 60;
  var cursor = start;
  var remaining = durationSec;

  // 걷기 구간 속도 ~90m/분, 나머지 거리를 러닝 구간에 배분
  final walkSecTotal =
      warmupSec + ((durationSec - warmupSec) ~/ (runSec + restSec)) * restSec;
  final walkM = walkSecTotal / 60 * 90;
  final runSecTotal = durationSec - walkSecTotal;
  final runSpeedMps = runSecTotal > 0 ? (totalM - walkM) / runSecTotal : 0.0;

  void add(String type, int sec) {
    if (sec <= 0) return;
    final end = cursor.add(Duration(seconds: sec));
    final isRun = type == 'running';
    segments.add(RunSegment(
      startTime: cursor,
      endTime: end,
      type: type,
      distanceM: isRun ? runSpeedMps * sec : sec / 60 * 90,
      avgHr: isRun ? 148 + rng.nextInt(12).toDouble() : 122 + rng.nextInt(8).toDouble(),
    ));
    cursor = end;
    remaining -= sec;
  }

  add('walking', warmupSec);
  while (remaining > runSec + restSec) {
    add('running', runSec);
    add('walking', restSec);
  }
  add('running', max(0, remaining - 60));
  add('walking', remaining);
  return segments;
}

/// 야간 러닝(21~22시, 강변 코스) 패턴의 데모 데이터 (PRD 1.1 배경 반영)
/// 4주 × 주 3회 = 12회. 마지막 회차는 10K 장거리 — 배지 다양하게 점등.
List<RunSession> _generateDemoRuns() {
  final rng = Random(42);
  final runs = <RunSession>[];
  final now = DateTime.now();

  for (int i = 0; i < 12; i++) {
    // 주 3회 패턴 (월·수·금 느낌): i를 3개씩 한 주로 묶음
    final week = i ~/ 3;
    final dayInWeek = (i % 3) * 2;
    final daysAgo = week * 7 + dayInWeek + 1;
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: daysAgo))
        .add(Duration(hours: 21, minutes: rng.nextInt(40)));
    // 최근일수록 거리·페이스 개선, i==0은 10K 장거리
    final km = i == 0
        ? 10.3
        : 3.0 + (11 - i) * 0.4 + rng.nextDouble() * 0.5;
    final paceSec = 415 + i * 5 + rng.nextInt(20); // 7'00"대에서 점진 개선
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
      steps: (durationSec / 60 * (162 + rng.nextInt(12))).round(),
      elevationM: 6 + rng.nextInt(20).toDouble(),
      segments: _demoSegments(start, durationSec, km * 1000, rng),
      splits: splits,
      hrSeries: hrSeries,
      sourceName: 'demo',
    ));
  }
  return runs;
}
