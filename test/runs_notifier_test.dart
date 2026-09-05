import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/providers.dart';

import 'support/fake_health_service.dart';
import 'support/in_memory_run_repository.dart';

RunSession _sampleRun({
  required String id,
  required DateTime startTime,
  double km = 5.0,
  int durationSec = 1800,
  double? avgHr = 145,
  double? maxHr = 165,
  String sourceName = 'Samsung Health',
}) {
  return RunSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSec)),
    distanceM: km * 1000,
    durationSec: durationSec,
    avgHr: avgHr,
    maxHr: maxHr,
    sourceName: sourceName,
  );
}

void main() {
  late InMemoryRunRepository repo;
  late FakeHealthService health;
  late ProviderContainer container;

  setUp(() {
    repo = InMemoryRunRepository();
    health = FakeHealthService();
    container = ProviderContainer(
      overrides: [
        repoProvider.overrideWithValue(repo),
        healthServiceProvider.overrideWithValue(health),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('RunsNotifier Initialization (build)', () {
    test('initializes with empty list when repository has no data', () async {
      final state = await container.read(runsProvider.future);
      expect(state, isEmpty);
      expect(container.read(runsProvider), isA<AsyncData<List<RunSession>>>());
    });

    test('initializes with sorted runs from repository (descending by startTime)',
        () async {
      final run1 = _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1, 9));
      final run2 = _sampleRun(id: 'r2', startTime: DateTime(2026, 8, 2, 9));
      final run3 = _sampleRun(id: 'r3', startTime: DateTime(2026, 7, 30, 9));
      await repo.upsertAll([run1, run2, run3]);

      final state = await container.read(runsProvider.future);

      expect(state.length, 3);
      expect(state.map((r) => r.id).toList(), ['r2', 'r1', 'r3']);
    });
  });

  group('RunsNotifier.sync', () {
    test('successfully syncs health data, updates VO2max, sets sync timestamp and evaluates achievements',
        () async {
      final run1 = _sampleRun(
        id: 'hc-1',
        startTime: DateTime(2026, 8, 10, 20),
        km: 5.2,
      );
      final run2 = _sampleRun(
        id: 'hc-2',
        startTime: DateTime(2026, 8, 11, 20),
        km: 10.5,
      );
      health.runsToReturn = [run1, run2];
      health.vo2SeriesToReturn = [
        (DateTime(2026, 8, 10), 45.5),
        (DateTime(2026, 8, 11), 46.0),
      ];

      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.sync();

      expect(result.error, isNull);
      expect(result.addedCount, 2);
      expect(result.newBadges, isNotEmpty);
      expect(health.configureCalled, isTrue);

      final state = container.read(runsProvider).value!;
      expect(state.length, 2);
      expect(state.first.id, 'hc-2');
      expect(state.last.id, 'hc-1');

      expect(repo.lastSyncedAt, isNotNull);
      expect(repo.getVo2Series().length, 2);
      expect(repo.getEarnedBadges(), isNotEmpty);
    });

    test('filters out ignoredIds during sync so deleted or ignored runs are not re-added',
        () async {
      final run1 = _sampleRun(id: 'ignore-1', startTime: DateTime(2026, 8, 1));
      final run2 = _sampleRun(id: 'valid-2', startTime: DateTime(2026, 8, 2));
      await repo.addIgnoredIds(['ignore-1']);
      health.runsToReturn = [run1, run2];

      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.sync();

      expect(result.error, isNull);
      expect(result.addedCount, 1);

      final state = container.read(runsProvider).value!;
      expect(state.length, 1);
      expect(state.first.id, 'valid-2');
    });

    test('does not overwrite VO2max series when health service returns empty VO2 data',
        () async {
      final initialVo2 = [(DateTime(2026, 8, 1), 44.0)];
      await repo.saveVo2Series(initialVo2);

      health.runsToReturn = [
        _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 2))
      ];
      health.vo2SeriesToReturn = [];

      final notifier = container.read(runsProvider.notifier);
      await notifier.sync();

      expect(repo.getVo2Series(), initialVo2);
    });

    test('returns error SyncResult when Health Connect permission is denied',
        () async {
      health.permissionGranted = false;

      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.sync();

      expect(result.error, 'Health Connect 권한이 거부되었습니다');
      expect(result.addedCount, 0);
      expect(result.newBadges, isEmpty);
    });

    test('handles exceptions during sync gracefully and returns error SyncResult',
        () async {
      health.fetchRunsError = StateError('Health Connect connection failed');

      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.sync();

      expect(result.error, contains('동기화 실패: Bad state: Health Connect connection failed'));
      expect(result.addedCount, 0);
    });
  });

  group('RunsNotifier.fetchCandidates', () {
    test('fetches candidates within 30 days without requesting history permission',
        () async {
      final from = DateTime.now().subtract(const Duration(days: 10));
      final candidate1 = _sampleRun(id: 'c1', startTime: DateTime.now().subtract(const Duration(days: 5)));
      final candidate2 = _sampleRun(id: 'c2', startTime: DateTime.now().subtract(const Duration(days: 2)));
      health.runsToReturn = [candidate1, candidate2];

      final notifier = container.read(runsProvider.notifier);
      final candidates = await notifier.fetchCandidates(from);

      expect(candidates.length, 2);
      expect(candidates.first.id, 'c2'); // sorted descending
      expect(candidates.last.id, 'c1');
      expect(health.lastFetchedSince, from);
    });

    test('requests history permission when from date is older than 29 days',
        () async {
      final from = DateTime.now().subtract(const Duration(days: 60));
      health.runsToReturn = [
        _sampleRun(id: 'c-old', startTime: DateTime.now().subtract(const Duration(days: 45)))
      ];

      final notifier = container.read(runsProvider.notifier);
      final candidates = await notifier.fetchCandidates(from);

      expect(candidates.length, 1);
      expect(candidates.first.id, 'c-old');
    });

    test('throws Exception when base permission is denied during candidate fetching',
        () async {
      health.permissionGranted = false;

      final notifier = container.read(runsProvider.notifier);

      expect(
        () => notifier.fetchCandidates(DateTime.now().subtract(const Duration(days: 5))),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Health Connect 권한이 거부되었습니다'),
        )),
      );
    });

    test('throws Exception when history permission is denied for > 29 days query',
        () async {
      health.historyPermissionGranted = false;

      final notifier = container.read(runsProvider.notifier);

      expect(
        () => notifier.fetchCandidates(DateTime.now().subtract(const Duration(days: 40))),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('과거 데이터 권한이 거부되어 최근 30일만 조회됩니다'),
        )),
      );
    });
  });

  group('RunsNotifier.importRuns', () {
    test('imports selected runs, manages ignored IDs, updates sync time, and triggers badge evaluation',
        () async {
      await repo.addIgnoredIds(['run-to-reselect', 'unrelated-ignored']);

      final run1 = _sampleRun(id: 'run-to-reselect', startTime: DateTime(2026, 7, 10), km: 5.0);
      final run2 = _sampleRun(id: 'new-run', startTime: DateTime(2026, 7, 11), km: 10.0);

      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.importRuns(
        [run1, run2],
        excludedIds: ['unselected-run-1', 'unselected-run-2'],
      );

      expect(result.addedCount, 2);
      expect(result.newBadges, isNotEmpty);

      final ignored = repo.getIgnoredIds();
      expect(ignored, containsAll(['unselected-run-1', 'unselected-run-2', 'unrelated-ignored']));
      expect(ignored, isNot(contains('run-to-reselect')));

      expect(repo.lastSyncedAt, isNotNull);
      final state = container.read(runsProvider).value!;
      expect(state.length, 2);
      expect(state.map((r) => r.id), containsAll(['run-to-reselect', 'new-run']));
    });
  });

  group('RunsNotifier.deleteRun', () {
    test('deletes run from repository, adds id to ignoredIds, and updates state',
        () async {
      final run1 = _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1));
      final run2 = _sampleRun(id: 'r2', startTime: DateTime(2026, 8, 2));
      await repo.upsertAll([run1, run2]);

      final notifier = container.read(runsProvider.notifier);
      await notifier.deleteRun('r1');

      final state = container.read(runsProvider).value!;
      expect(state.length, 1);
      expect(state.first.id, 'r2');
      expect(repo.getById('r1'), isNull);
      expect(repo.getIgnoredIds(), contains('r1'));
    });
  });

  group('RunsNotifier.seedDemoData and clearAll', () {
    test('seedDemoData generates 12 demo runs, evaluates badges, and populates state',
        () async {
      final notifier = container.read(runsProvider.notifier);
      final result = await notifier.seedDemoData();

      expect(result.addedCount, 12);
      expect(result.newBadges, isNotEmpty);

      final state = container.read(runsProvider).value!;
      expect(state.length, 12);
      expect(state.first.id, startsWith('demo-'));
    });

    test('clearAll clears repository data and updates state to empty list',
        () async {
      final run = _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1));
      await repo.upsertAll([run]);

      final notifier = container.read(runsProvider.notifier);
      await notifier.clearAll();

      expect(repo.clearCount, 1);
      final state = container.read(runsProvider).value!;
      expect(state, isEmpty);
    });
  });

  group('MutationQueue Integration and Concurrency', () {
    test('executes concurrent mutation calls in strict sequential FIFO order',
        () async {
      final order = <String>[];

      final notifier = container.read(runsProvider.notifier);

      // Run 3 async operations concurrently without awaiting the first before launching the next
      final op1 = notifier.importRuns([
        _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1)),
      ]).then((_) => order.add('import'));

      final op2 = notifier.deleteRun('r1').then((_) => order.add('delete'));

      final op3 = notifier.clearAll().then((_) => order.add('clear'));

      await Future.wait([op1, op2, op3]);

      expect(order, ['import', 'delete', 'clear']);
      expect(container.read(runsProvider).value, isEmpty);
    });

    test('continues subsequent mutations even if a prior mutation in queue throws an error',
        () async {
      // Invalidate repo temporarily to simulate failure
      final run1 = _sampleRun(id: 'valid-r1', startTime: DateTime(2026, 8, 1));

      final notifier = container.read(runsProvider.notifier);

      // Trigger sync with mock failure
      health.fetchRunsError = Exception('Network down');
      final syncResult = await notifier.sync();
      expect(syncResult.error, contains('Network down'));

      // Next mutation should proceed normally
      await notifier.importRuns([run1]);
      final state = container.read(runsProvider).value!;
      expect(state.length, 1);
      expect(state.first.id, 'valid-r1');
    });
  });

  group('Derived Providers Reactivity', () {
    test('statsProvider, vo2SeriesProvider, and earnedBadgesProvider update on state changes',
        () async {
      final run1 = _sampleRun(id: 'r1', startTime: DateTime.now(), km: 6.0, durationSec: 2160);
      final run2 = _sampleRun(id: 'r2', startTime: DateTime.now().subtract(const Duration(days: 2)), km: 4.0, durationSec: 1440);

      // Initial stats
      expect(container.read(statsProvider).totalKm, 0.0);
      expect(container.read(earnedBadgesProvider), isEmpty);
      expect(container.read(vo2SeriesProvider), isEmpty);

      // Add runs & vo2
      await repo.saveVo2Series([(DateTime.now(), 48.0)]);
      await container.read(runsProvider.notifier).importRuns([run1, run2]);

      final stats = container.read(statsProvider);
      expect(stats.totalKm, 10.0);
      expect(stats.totalRuns, 2);

      final badges = container.read(earnedBadgesProvider);
      expect(badges, isNotEmpty);
      expect(badges.containsKey('first_run'), isTrue);

      final vo2 = container.read(vo2SeriesProvider);
      expect(vo2.length, 1);
      expect(vo2.first.$2, 48.0);
    });
  });
}
