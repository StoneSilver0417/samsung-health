import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/models/achievement.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/repositories/run_repository.dart';

import 'support/in_memory_run_repository.dart';

RunSession _sampleRun({
  required String id,
  required DateTime startTime,
  double km = 5.0,
  int durationSec = 1800,
}) {
  return RunSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSec)),
    distanceM: km * 1000,
    durationSec: durationSec,
  );
}

void main() {
  group('RunStore Operations', () {
    late InMemoryRunStore store;

    setUp(() {
      store = InMemoryRunStore();
    });

    test('upsertAll inserts new runs and returns only newly added runs', () async {
      final run1 = _sampleRun(id: 'r1', startTime: DateTime(2026, 9, 1, 10));
      final run2 = _sampleRun(id: 'r2', startTime: DateTime(2026, 9, 2, 10));

      final addedFirst = await store.upsertAll([run1, run2]);
      expect(addedFirst.length, 2);
      expect(addedFirst.map((r) => r.id), containsAll(['r1', 'r2']));

      final run3 = _sampleRun(id: 'r3', startTime: DateTime(2026, 9, 3, 10));
      final addedSecond = await store.upsertAll([run1, run3]);
      expect(addedSecond.length, 1);
      expect(addedSecond.first.id, 'r3');

      final all = await store.getAll();
      expect(all.length, 3);
      expect(all.first.id, 'r3'); // descending by startTime
    });

    test('getById and delete operate correctly', () async {
      final run1 = _sampleRun(id: 'r1', startTime: DateTime(2026, 9, 1, 10));
      await store.upsertAll([run1]);

      expect(store.getById('r1')?.id, 'r1');
      expect(store.getById('non-existent'), isNull);

      await store.delete('r1');
      expect(store.getById('r1'), isNull);
      expect(await store.getAll(), isEmpty);
    });

    test('lastSyncedAt stores and retrieves timestamp', () async {
      expect(store.lastSyncedAt, isNull);
      final syncTime = DateTime(2026, 9, 5, 12, 30);
      await store.setLastSyncedAt(syncTime);
      expect(store.lastSyncedAt, syncTime);
    });

    test('ignoredIds add, get, and remove operations', () async {
      expect(store.getIgnoredIds(), isEmpty);

      await store.addIgnoredIds(['id-1', 'id-2', 'id-3']);
      expect(store.getIgnoredIds(), {'id-1', 'id-2', 'id-3'});

      await store.removeIgnoredIds(['id-2']);
      expect(store.getIgnoredIds(), {'id-1', 'id-3'});
    });

    test('vo2Series save and retrieve', () async {
      expect(store.getVo2Series(), isEmpty);

      final series = [
        (DateTime(2026, 9, 1), 48.5),
        (DateTime(2026, 9, 2), 49.0),
      ];
      await store.saveVo2Series(series);
      final retrieved = store.getVo2Series();
      expect(retrieved.length, 2);
      expect(retrieved[0].$2, 48.5);
      expect(retrieved[1].$2, 49.0);
    });

    test('clear resets runs, ignoredIds, vo2Series, and lastSyncedAt', () async {
      await store.upsertAll([
        _sampleRun(id: 'r1', startTime: DateTime(2026, 9, 1)),
      ]);
      await store.addIgnoredIds(['id-1']);
      await store.saveVo2Series([(DateTime(2026, 9, 1), 48.5)]);
      await store.setLastSyncedAt(DateTime(2026, 9, 1));

      await store.clear();

      expect(await store.getAll(), isEmpty);
      expect(store.getIgnoredIds(), isEmpty);
      expect(store.getVo2Series(), isEmpty);
      expect(store.lastSyncedAt, isNull);
    });
  });

  group('AchievementStore Operations', () {
    late InMemoryAchievementStore store;

    setUp(() {
      store = InMemoryAchievementStore();
    });

    test('saveEarnedBadges and getEarnedBadges', () async {
      expect(store.getEarnedBadges(), isEmpty);

      final badge1 = EarnedBadge(
        badgeId: 'first_5k',
        earnedAt: DateTime(2026, 9, 1),
        runId: 'r1',
      );
      final badge2 = EarnedBadge(
        badgeId: 'night_owl',
        earnedAt: DateTime(2026, 9, 2),
      );

      await store.saveEarnedBadges([badge1, badge2]);
      final earned = store.getEarnedBadges();
      expect(earned.length, 2);
      expect(earned.map((b) => b.badgeId), containsAll(['first_5k', 'night_owl']));

      await store.clear();
      expect(store.getEarnedBadges(), isEmpty);
    });
  });

  group('SettingsStore Operations', () {
    late InMemorySettingsStore store;

    setUp(() {
      store = InMemorySettingsStore();
    });

    test('getGeminiApiKey and setGeminiApiKey', () async {
      expect(store.getGeminiApiKey(), isNull);

      await store.setGeminiApiKey('AIzaSyTest123');
      expect(store.getGeminiApiKey(), 'AIzaSyTest123');

      await store.setGeminiApiKey(null);
      expect(store.getGeminiApiKey(), isNull);
    });

    test('AI Summary save and get', () async {
      expect(store.getAiSummary('run-1'), isNull);

      await store.saveAiSummary('run-1', 'Great run with steady pace!');
      expect(store.getAiSummary('run-1'), 'Great run with steady pace!');
    });

    test('Goal recommendation and timestamp save/get', () async {
      expect(store.getGoalRecommendation(), isNull);
      expect(store.getGoalRecommendedAt(), isNull);

      final now = DateTime(2026, 9, 5, 14, 0);
      await store.saveGoalRecommendation('Target: 5km at 5:30 pace', now);

      expect(store.getGoalRecommendation(), 'Target: 5km at 5:30 pace');
      expect(store.getGoalRecommendedAt(), now);
    });

    test('clearCache resets AI summaries and goal recommendations but retains API key', () async {
      await store.setGeminiApiKey('AIzaSyTest123');
      await store.saveAiSummary('run-1', 'Summary 1');
      await store.saveGoalRecommendation('Target 1', DateTime.now());

      await store.clearCache();

      expect(store.getGeminiApiKey(), 'AIzaSyTest123');
      expect(store.getAiSummary('run-1'), isNull);
      expect(store.getGoalRecommendation(), isNull);
      expect(store.getGoalRecommendedAt(), isNull);
    });
  });

  group('RunRepository Facade Coordination', () {
    late InMemoryRunStore runStore;
    late InMemoryAchievementStore achievementStore;
    late InMemorySettingsStore settingsStore;
    late HiveRunRepository facadeRepo;

    setUp(() {
      runStore = InMemoryRunStore();
      achievementStore = InMemoryAchievementStore();
      settingsStore = InMemorySettingsStore();
      facadeRepo = HiveRunRepository(
        runStore: runStore,
        achievementStore: achievementStore,
        settingsStore: settingsStore,
      );
    });

    test('facade delegates all store operations and coordinates clear', () async {
      // Runs delegation
      final run = _sampleRun(id: 'r-facade', startTime: DateTime(2026, 9, 1));
      await facadeRepo.upsertAll([run]);
      expect((await facadeRepo.getAll()).length, 1);
      expect(facadeRepo.getById('r-facade')?.id, 'r-facade');

      // Sync & VO2 delegation
      await facadeRepo.setLastSyncedAt(DateTime(2026, 9, 2));
      expect(facadeRepo.lastSyncedAt, DateTime(2026, 9, 2));
      await facadeRepo.addIgnoredIds(['ignore-1']);
      expect(facadeRepo.getIgnoredIds(), {'ignore-1'});
      await facadeRepo.saveVo2Series([(DateTime(2026, 9, 1), 48.0)]);
      expect(facadeRepo.getVo2Series().length, 1);

      // Achievement delegation
      await facadeRepo.saveEarnedBadges([
        EarnedBadge(badgeId: 'first_run', earnedAt: DateTime(2026, 9, 1)),
      ]);
      expect(facadeRepo.getEarnedBadges().length, 1);

      // Settings delegation
      await facadeRepo.setGeminiApiKey('test-key');
      expect(facadeRepo.getGeminiApiKey(), 'test-key');
      await facadeRepo.saveAiSummary('r-facade', 'Facade AI summary');
      expect(facadeRepo.getAiSummary('r-facade'), 'Facade AI summary');
      await facadeRepo.saveGoalRecommendation('Goal 1', DateTime(2026, 9, 3));
      expect(facadeRepo.getGoalRecommendation(), 'Goal 1');
      expect(facadeRepo.getGoalRecommendedAt(), DateTime(2026, 9, 3));

      // Coordinated clear()
      await facadeRepo.clear();

      expect(await facadeRepo.getAll(), isEmpty);
      expect(facadeRepo.getEarnedBadges(), isEmpty);
      expect(facadeRepo.getAiSummary('r-facade'), isNull);
      expect(facadeRepo.getGoalRecommendation(), isNull);
      expect(facadeRepo.getGoalRecommendedAt(), isNull);
      expect(facadeRepo.getIgnoredIds(), isEmpty);
      expect(facadeRepo.getVo2Series(), isEmpty);
      expect(facadeRepo.lastSyncedAt, isNull);
      // API key remains intact across cache clear
      expect(facadeRepo.getGeminiApiKey(), 'test-key');
    });

    test('facade exposes store getters', () {
      expect(facadeRepo.runStore, same(runStore));
      expect(facadeRepo.achievementStore, same(achievementStore));
      expect(facadeRepo.settingsStore, same(settingsStore));
    });
  });
}
