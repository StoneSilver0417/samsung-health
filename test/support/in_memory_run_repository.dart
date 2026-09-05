import 'package:runlog/data/run_repository.dart';
import 'package:runlog/models/achievement.dart';
import 'package:runlog/models/run_session.dart';

class InMemoryRunStore implements RunStore {
  final Map<String, RunSession> runs;
  final Set<String> ignoredIds;
  List<(DateTime, double)> vo2Series;
  DateTime? syncedAt;
  Object? getAllError;
  Future<List<RunSession>>? getAllFuture;

  InMemoryRunStore({
    Map<String, RunSession>? runs,
    Set<String>? ignoredIds,
    List<(DateTime, double)>? vo2Series,
    this.syncedAt,
  })  : runs = runs ?? {},
        ignoredIds = ignoredIds ?? {},
        vo2Series = vo2Series ?? [];

  @override
  Future<List<RunSession>> getAll() async {
    if (getAllFuture != null) return getAllFuture!;
    if (getAllError != null) throw getAllError!;
    return runs.values.toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
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
    runs.clear();
    ignoredIds.clear();
    vo2Series.clear();
    syncedAt = null;
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
}

class InMemoryAchievementStore implements AchievementStore {
  final Map<String, EarnedBadge> badges;

  InMemoryAchievementStore({Map<String, EarnedBadge>? badges})
      : badges = badges ?? {};

  @override
  List<EarnedBadge> getEarnedBadges() => badges.values.toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> incoming) async {
    for (final badge in incoming) {
      badges[badge.badgeId] = badge;
    }
  }

  @override
  Future<void> clear() async => badges.clear();
}

class InMemorySettingsStore implements SettingsStore {
  String? apiKey;
  final Map<String, String> summaries;
  String? goalRecommendation;
  DateTime? goalRecommendedAt;

  InMemorySettingsStore({
    this.apiKey,
    Map<String, String>? summaries,
    this.goalRecommendation,
    this.goalRecommendedAt,
  }) : summaries = summaries ?? {};

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

  @override
  Future<void> clearCache() async {
    summaries.clear();
    goalRecommendation = null;
    goalRecommendedAt = null;
  }
}

class InMemoryRunRepository implements RunRepository {
  final InMemoryRunStore _runStore;
  final InMemoryAchievementStore _achievementStore;
  final InMemorySettingsStore _settingsStore;
  int clearCount = 0;

  InMemoryRunRepository({
    Iterable<RunSession> initialRuns = const [],
    InMemoryRunStore? runStore,
    InMemoryAchievementStore? achievementStore,
    InMemorySettingsStore? settingsStore,
  })  : _runStore = runStore ?? InMemoryRunStore(),
        _achievementStore = achievementStore ?? InMemoryAchievementStore(),
        _settingsStore = settingsStore ?? InMemorySettingsStore() {
    for (final run in initialRuns) {
      _runStore.runs[run.id] = run;
    }
  }

  RunStore get runStore => _runStore;
  AchievementStore get achievementStore => _achievementStore;
  SettingsStore get settingsStore => _settingsStore;

  Map<String, RunSession> get runs => _runStore.runs;
  Map<String, EarnedBadge> get badges => _achievementStore.badges;
  Set<String> get ignoredIds => _runStore.ignoredIds;
  List<(DateTime, double)> get vo2Series => _runStore.vo2Series;
  set vo2Series(List<(DateTime, double)> v) => _runStore.vo2Series = v;
  DateTime? get syncedAt => _runStore.syncedAt;
  set syncedAt(DateTime? v) => _runStore.syncedAt = v;
  String? get apiKey => _settingsStore.apiKey;
  set apiKey(String? v) => _settingsStore.apiKey = v;
  Map<String, String> get summaries => _settingsStore.summaries;
  String? get goalRecommendation => _settingsStore.goalRecommendation;
  set goalRecommendation(String? v) => _settingsStore.goalRecommendation = v;
  DateTime? get goalRecommendedAt => _settingsStore.goalRecommendedAt;
  set goalRecommendedAt(DateTime? v) => _settingsStore.goalRecommendedAt = v;
  Object? get getAllError => _runStore.getAllError;
  set getAllError(Object? v) => _runStore.getAllError = v;
  Future<List<RunSession>>? get getAllFuture => _runStore.getAllFuture;
  set getAllFuture(Future<List<RunSession>>? v) => _runStore.getAllFuture = v;

  @override
  Future<List<RunSession>> getAll() => _runStore.getAll();

  @override
  RunSession? getById(String id) => _runStore.getById(id);

  @override
  Future<List<RunSession>> upsertAll(List<RunSession> incoming) =>
      _runStore.upsertAll(incoming);

  @override
  Future<void> delete(String id) => _runStore.delete(id);

  @override
  Future<void> clear() async {
    clearCount++;
    await _runStore.clear();
    await _achievementStore.clear();
    await _settingsStore.clearCache();
  }

  @override
  DateTime? get lastSyncedAt => _runStore.lastSyncedAt;

  @override
  Future<void> setLastSyncedAt(DateTime time) =>
      _runStore.setLastSyncedAt(time);

  @override
  Set<String> getIgnoredIds() => _runStore.getIgnoredIds();

  @override
  Future<void> addIgnoredIds(Iterable<String> ids) =>
      _runStore.addIgnoredIds(ids);

  @override
  Future<void> removeIgnoredIds(Iterable<String> ids) =>
      _runStore.removeIgnoredIds(ids);

  @override
  List<(DateTime, double)> getVo2Series() => _runStore.getVo2Series();

  @override
  Future<void> saveVo2Series(List<(DateTime, double)> series) =>
      _runStore.saveVo2Series(series);

  @override
  List<EarnedBadge> getEarnedBadges() => _achievementStore.getEarnedBadges();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> incoming) =>
      _achievementStore.saveEarnedBadges(incoming);

  @override
  String? getGeminiApiKey() => _settingsStore.getGeminiApiKey();

  @override
  Future<void> setGeminiApiKey(String? key) =>
      _settingsStore.setGeminiApiKey(key);

  @override
  String? getAiSummary(String runId) => _settingsStore.getAiSummary(runId);

  @override
  Future<void> saveAiSummary(String runId, String summary) =>
      _settingsStore.saveAiSummary(runId, summary);

  @override
  String? getGoalRecommendation() => _settingsStore.getGoalRecommendation();

  @override
  Future<void> saveGoalRecommendation(String text, DateTime at) =>
      _settingsStore.saveGoalRecommendation(text, at);

  @override
  DateTime? getGoalRecommendedAt() => _settingsStore.getGoalRecommendedAt();
}
