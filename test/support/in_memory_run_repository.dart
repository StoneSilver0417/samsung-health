import 'package:runlog/data/run_repository.dart';
import 'package:runlog/models/achievement.dart';
import 'package:runlog/models/run_session.dart';

class InMemoryRunRepository implements RunRepository {
  final Map<String, RunSession> runs = {};
  final Map<String, EarnedBadge> badges = {};
  final Set<String> ignoredIds = {};
  List<(DateTime, double)> vo2Series = [];
  DateTime? syncedAt;
  String? apiKey;
  final Map<String, String> summaries = {};
  String? goalRecommendation;
  DateTime? goalRecommendedAt;
  int clearCount = 0;
  Object? getAllError;
  Future<List<RunSession>>? getAllFuture;

  InMemoryRunRepository({Iterable<RunSession> initialRuns = const []}) {
    for (final run in initialRuns) {
      runs[run.id] = run;
    }
  }

  @override
  Future<List<RunSession>> getAll() async {
    if (getAllFuture != null) return getAllFuture!;
    if (getAllError != null) throw getAllError!;
    return runs.values.toList()..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  @override
  RunSession? getById(String id) => runs[id];

  @override
  Future<List<RunSession>> upsertAll(List<RunSession> incoming) async {
    final added = <RunSession>[];
    for (final run in incoming) {
      if (!runs.containsKey(run.id)) added.add(run);
      runs[run.id] = run;
    }
    return added;
  }

  @override
  Future<void> delete(String id) async => runs.remove(id);

  @override
  Future<void> clear() async {
    clearCount++;
    runs.clear();
    badges.clear();
    ignoredIds.clear();
    vo2Series.clear();
    syncedAt = null;
    summaries.clear();
    goalRecommendation = null;
    goalRecommendedAt = null;
  }

  @override
  DateTime? get lastSyncedAt => syncedAt;

  @override
  Future<void> setLastSyncedAt(DateTime time) async => syncedAt = time;

  @override
  Set<String> getIgnoredIds() => Set.unmodifiable(ignoredIds);

  @override
  Future<void> addIgnoredIds(Iterable<String> ids) async =>
      ignoredIds.addAll(ids);

  @override
  Future<void> removeIgnoredIds(Iterable<String> ids) async =>
      ignoredIds.removeAll(ids);

  @override
  List<(DateTime, double)> getVo2Series() => List.unmodifiable(vo2Series);

  @override
  Future<void> saveVo2Series(List<(DateTime, double)> series) async =>
      vo2Series = List.of(series);

  @override
  List<EarnedBadge> getEarnedBadges() => badges.values.toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> incoming) async {
    for (final badge in incoming) {
      badges[badge.badgeId] = badge;
    }
  }

  @override
  String? getGeminiApiKey() => apiKey;

  @override
  Future<void> setGeminiApiKey(String? key) async => apiKey = key;

  @override
  String? getAiSummary(String runId) => summaries[runId];

  @override
  Future<void> saveAiSummary(String runId, String summary) async =>
      summaries[runId] = summary;

  @override
  String? getGoalRecommendation() => goalRecommendation;

  @override
  Future<void> saveGoalRecommendation(String text, DateTime at) async {
    goalRecommendation = text;
    goalRecommendedAt = at;
  }

  @override
  DateTime? getGoalRecommendedAt() => goalRecommendedAt;
}
