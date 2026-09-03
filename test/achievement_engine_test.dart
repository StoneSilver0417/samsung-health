import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/data/run_repository.dart';
import 'package:runlog/logic/achievement_engine.dart';
import 'package:runlog/models/achievement.dart';
import 'package:runlog/models/run_session.dart';

class _FakeRepo implements RunRepository {
  final Map<String, EarnedBadge> _badges = {};

  @override
  List<EarnedBadge> getEarnedBadges() => _badges.values.toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> badges) async {
    for (final b in badges) {
      _badges[b.badgeId] = b;
    }
  }

  @override
  Future<List<RunSession>> getAll() async => const [];
  @override
  RunSession? getById(String id) => null;
  @override
  Future<List<RunSession>> upsertAll(List<RunSession> runs) async => runs;
  @override
  Future<void> delete(String id) async {}
  @override
  Future<void> clear() async {}
  @override
  DateTime? get lastSyncedAt => null;
  @override
  Future<void> setLastSyncedAt(DateTime t) async {}
  @override
  Set<String> getIgnoredIds() => const {};
  @override
  Future<void> addIgnoredIds(Iterable<String> ids) async {}
  @override
  Future<void> removeIgnoredIds(Iterable<String> ids) async {}
  @override
  List<(DateTime, double)> getVo2Series() => const [];
  @override
  Future<void> saveVo2Series(List<(DateTime, double)> series) async {}
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

RunSession _session({
  required String id,
  required DateTime startTime,
  required double km,
  required int durationSec,
  double? calories,
}) {
  return RunSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSec)),
    distanceM: km * 1000,
    durationSec: durationSec,
    calories: calories,
  );
}

void main() {
  late _FakeRepo repo;
  late AchievementEngine engine;

  setUp(() {
    repo = _FakeRepo();
    engine = AchievementEngine(repo);
  });

  test('kBadges contains 33 total badges including all 8 new definitions', () {
    expect(kBadges.length, 33);
    final ids = kBadges.map((b) => b.id).toSet();
    expect(ids, containsAll([
      'first_3k',
      'first_full',
      'total_2000k',
      'streak_12w',
      'month_15runs',
      'speed_sub5',
      'calorie_1000',
      'consecutive_2days',
    ]));
  });

  test('first_3k and first_full distance achievements', () async {
    final runs = [
      _session(
        id: '1',
        startTime: DateTime(2026, 8, 1, 20),
        km: 3.5,
        durationSec: 1200,
      ),
      _session(
        id: '2',
        startTime: DateTime(2026, 8, 5, 20),
        km: 42.5,
        durationSec: 14400,
      ),
    ];

    final earned = await engine.evaluate(runs);
    final earnedIds = earned.map((b) => b.id).toSet();

    expect(earnedIds, contains('first_3k'));
    expect(earnedIds, contains('first_full'));
  });

  test('total_2000k cumulative distance achievement', () async {
    final runs = [
      _session(
        id: '1',
        startTime: DateTime(2026, 1, 1),
        km: 1000.0,
        durationSec: 360000,
      ),
      _session(
        id: '2',
        startTime: DateTime(2026, 6, 1),
        km: 1050.0,
        durationSec: 378000,
      ),
    ];

    final earned = await engine.evaluate(runs);
    final earnedIds = earned.map((b) => b.id).toSet();

    expect(earnedIds, contains('total_1000k'));
    expect(earnedIds, contains('total_2000k'));
  });

  test('consecutive_2days and calorie_1000 and speed_sub5 achievements', () async {
    final runs = [
      _session(
        id: '1',
        startTime: DateTime(2026, 8, 1, 21),
        km: 5.0,
        durationSec: 1400, // pace: 280 s/km (sub5)
        calories: 1050.0,  // calorie >= 1000
      ),
      _session(
        id: '2',
        startTime: DateTime(2026, 8, 2, 21), // next calendar day (consecutive)
        km: 3.0,
        durationSec: 900,
        calories: 300.0,
      ),
    ];

    final earned = await engine.evaluate(runs);
    final earnedIds = earned.map((b) => b.id).toSet();

    expect(earnedIds, contains('speed_sub5'));
    expect(earnedIds, contains('calorie_1000'));
    expect(earnedIds, contains('consecutive_2days'));
  });

  test('month_15runs achievement when 15 runs in the same month', () async {
    final runs = List.generate(
      15,
      (i) => _session(
        id: 'run_$i',
        startTime: DateTime(2026, 8, i + 1, 20),
        km: 2.0,
        durationSec: 720,
      ),
    );

    final earned = await engine.evaluate(runs);
    final earnedIds = earned.map((b) => b.id).toSet();

    expect(earnedIds, contains('month_10runs'));
    expect(earnedIds, contains('month_15runs'));
  });
}
