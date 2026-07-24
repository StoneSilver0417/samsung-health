import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/data/run_repository.dart';
import 'package:runlog/logic/achievement_engine.dart';
import 'package:runlog/models/achievement.dart';
import 'package:runlog/models/run_session.dart';

/// providers.dart의 importRuns()가 실제로 사용하는 RunRepository 흐름을
/// 메모리 위에서 그대로 재현하는 가짜 저장소 — Hive/플랫폼 채널 없이
/// AchievementEngine 연동을 단위 테스트하기 위함.
class FakeRunRepository implements RunRepository {
  final Map<String, RunSession> _runs = {};
  final Map<String, EarnedBadge> _badges = {};
  final Set<String> _ignored = {};
  DateTime? _lastSyncedAt;

  @override
  Future<List<RunSession>> getAll() async {
    final list = _runs.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  RunSession? getById(String id) => _runs[id];

  @override
  Future<List<RunSession>> upsertAll(List<RunSession> runs) async {
    final added = <RunSession>[];
    for (final run in runs) {
      if (!_runs.containsKey(run.id)) added.add(run);
      _runs[run.id] = run;
    }
    return added;
  }

  @override
  Future<void> delete(String id) async => _runs.remove(id);

  @override
  Future<void> clear() async {
    _runs.clear();
    _badges.clear();
    _ignored.clear();
    _lastSyncedAt = null;
  }

  @override
  DateTime? get lastSyncedAt => _lastSyncedAt;

  @override
  Future<void> setLastSyncedAt(DateTime t) async => _lastSyncedAt = t;

  @override
  Set<String> getIgnoredIds() => _ignored;

  @override
  Future<void> addIgnoredIds(Iterable<String> ids) async => _ignored.addAll(ids);

  @override
  Future<void> removeIgnoredIds(Iterable<String> ids) async =>
      _ignored.removeAll(ids);

  @override
  List<(DateTime, double)> getVo2Series() => const [];

  @override
  Future<void> saveVo2Series(List<(DateTime, double)> series) async {}

  @override
  List<EarnedBadge> getEarnedBadges() => _badges.values.toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> badges) async {
    for (final b in badges) {
      _badges[b.badgeId] = b;
    }
  }

  @override
  String? getGeminiApiKey() => null;

  @override
  Future<void> setGeminiApiKey(String? key) async {}

  @override
  String? getAiSummary(String runId) => null;

  @override
  Future<void> saveAiSummary(String runId, String summary) async {}

  @override
  String? getGoalRecommendation() => null;

  @override
  Future<void> saveGoalRecommendation(String text, DateTime at) async {}

  @override
  DateTime? getGoalRecommendedAt() => null;
}

/// providers.dart의 RunsNotifier.importRuns()와 동일한 순서로
/// upsert → 업적 재평가를 수행한다 (수동 추가/수정 화면이 실제로 타는 경로).
Future<List<BadgeDef>> importRuns(
    FakeRunRepository repo, List<RunSession> selected) async {
  await repo.upsertAll(selected);
  await repo.removeIgnoredIds(selected.map((r) => r.id));
  await repo.setLastSyncedAt(DateTime.now());
  final all = await repo.getAll();
  return AchievementEngine(repo).evaluate(all.reversed.toList());
}

RunSession manualRun({
  required String id,
  required DateTime startTime,
  required double distanceKm,
  required int durationSec,
  double? avgHr,
  double? maxHr,
}) {
  return RunSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSec)),
    distanceM: distanceKm * 1000,
    durationSec: durationSec,
    avgHr: avgHr,
    maxHr: maxHr,
    sourceName: 'manual',
  );
}

void main() {
  group('수동 기록 추가 → 업적 연동', () {
    test('첫 수동 기록 추가 시 거리 기반 업적이 실제 러닝 날짜로 즉시 획득된다', () async {
      final repo = FakeRunRepository();
      final runDate = DateTime(2026, 7, 1, 21, 30); // 삼성헬스 동기화 장애 구간의 과거 날짜
      final run = manualRun(
        id: 'manual-1',
        startTime: runDate,
        distanceKm: 5.2,
        durationSec: 32 * 60,
        avgHr: 150,
        maxHr: 168,
      );

      final newBadges = await importRuns(repo, [run]);
      final badgeIds = newBadges.map((b) => b.id).toSet();

      // 첫 러닝 + 첫 5km 업적이 즉시 잡혀야 한다
      expect(badgeIds, containsAll(['first_run', 'first_5k']));

      final earned = {for (final e in repo.getEarnedBadges()) e.badgeId: e};
      // earnedAt이 "오늘"(DateTime.now())이 아니라 수동 입력한 러닝 날짜여야 한다
      // — v1.5.0에서 고친 "업적 날짜가 항상 오늘로 찍히는 버그"가 수동 기록에도
      // 똑같이 적용되는지가 이번 검증의 핵심.
      expect(earned['first_run']!.earnedAt, runDate);
      expect(earned['first_5k']!.earnedAt, runDate);
      expect(earned['first_run']!.earnedAt.isBefore(DateTime.now()), isTrue);
    });

    test('기존 Health Connect 동기화 기록과 수동 기록이 누적 거리 업적을 함께 채운다', () async {
      final repo = FakeRunRepository();
      // 기존에 HC로 동기화된 기록 45km 누적
      final synced = List.generate(9, (i) {
        return RunSession(
          id: 'hc-$i',
          startTime: DateTime(2026, 6, 1 + i, 21),
          endTime: DateTime(2026, 6, 1 + i, 21, 30),
          distanceM: 5000,
          durationSec: 1800,
          sourceName: 'Samsung Health',
        );
      });
      await repo.upsertAll(synced);
      await AchievementEngine(repo)
          .evaluate((await repo.getAll()).reversed.toList());
      expect(repo.getEarnedBadges().any((b) => b.badgeId == 'total_50k'),
          isFalse);

      // 수동으로 6km를 추가 입력하면 누적 51km가 되어 50km 업적을 넘겨야 한다
      final manualDate = DateTime(2026, 6, 10, 22);
      final manual = manualRun(
        id: 'manual-fill',
        startTime: manualDate,
        distanceKm: 6.0,
        durationSec: 36 * 60,
      );
      final newBadges = await importRuns(repo, [manual]);

      expect(newBadges.map((b) => b.id), contains('total_50k'));
      final earned = {for (final e in repo.getEarnedBadges()) e.badgeId: e};
      // 임계값을 처음 넘긴 러닝(시간순으로 정렬했을 때)의 날짜가 찍혀야 한다
      expect(earned['total_50k'], isNotNull);
    });

    test('수동 기록 수정(같은 id로 덮어쓰기)은 이미 획득한 업적을 재발급하지 않는다', () async {
      final repo = FakeRunRepository();
      final original = manualRun(
        id: 'manual-edit-target',
        startTime: DateTime(2026, 7, 5, 21),
        distanceKm: 5.0,
        durationSec: 30 * 60,
      );
      final firstBadges = await importRuns(repo, [original]);
      expect(firstBadges.map((b) => b.id), contains('first_5k'));

      // 같은 id로 거리만 10km로 수정 (ManualAddScreen 편집 저장과 동일한 흐름)
      final edited = manualRun(
        id: 'manual-edit-target',
        startTime: DateTime(2026, 7, 5, 21),
        distanceKm: 10.0,
        durationSec: 55 * 60,
      );
      final secondBadges = await importRuns(repo, [edited]);

      // first_10k는 새로 획득되어야 하고, first_5k는 이미 획득된 상태라 중복 발급 안 됨
      expect(secondBadges.map((b) => b.id), contains('first_10k'));
      expect(secondBadges.map((b) => b.id), isNot(contains('first_5k')));

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.distanceKm, 10.0); // 덮어쓰기 확인 — 중복 저장 안 됨
    });

    test('수동 기록은 sourceName과 무관하게 야간/주말 등 스페셜 업적 조건에도 동일하게 반영된다',
        () async {
      final repo = FakeRunRepository();
      // 22시 야간 러닝 10회를 수동으로 입력
      final runs = List.generate(10, (i) {
        return manualRun(
          id: 'manual-night-$i',
          startTime: DateTime(2026, 5, 1 + i, 22),
          distanceKm: 3.0,
          durationSec: 20 * 60,
        );
      });
      final newBadges = await importRuns(repo, runs);

      expect(newBadges.map((b) => b.id), contains('night_owl'));
    });
  });
}
