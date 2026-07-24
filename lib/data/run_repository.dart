import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../models/achievement.dart';
import '../models/run_session.dart';

/// 저장소 추상화. Phase 1은 Hive 로컬 단독, v2에서 Firestore 어댑터 추가 예정 (PRD 5).
abstract class RunRepository {
  Future<List<RunSession>> getAll();
  RunSession? getById(String id);

  /// 세션 UUID 기준 dedupe 후 저장. 새로 추가된 세션만 반환.
  Future<List<RunSession>> upsertAll(List<RunSession> runs);

  Future<void> delete(String id);
  Future<void> clear();

  DateTime? get lastSyncedAt;
  Future<void> setLastSyncedAt(DateTime t);

  /// 동기화에서 영구 제외할 세션 ID (가져오기에서 체크 해제했거나 삭제한 기록)
  Set<String> getIgnoredIds();
  Future<void> addIgnoredIds(Iterable<String> ids);
  Future<void> removeIgnoredIds(Iterable<String> ids);

  /// VO2max 시계열 캐시 (시간, 값)
  List<(DateTime, double)> getVo2Series();
  Future<void> saveVo2Series(List<(DateTime, double)> series);

  List<EarnedBadge> getEarnedBadges();
  Future<void> saveEarnedBadges(List<EarnedBadge> badges);

  /// Gemini API 키 (기기 로컬 저장만, git에는 절대 포함되지 않음)
  String? getGeminiApiKey();
  Future<void> setGeminiApiKey(String? key);

  /// 세션별 AI 요약 캐시 (같은 러닝을 다시 열 때 API 재호출 방지)
  String? getAiSummary(String runId);
  Future<void> saveAiSummary(String runId, String summary);

  /// AI 목표 추천 캐시 (분석 탭 재진입 시 API 재호출 방지)
  String? getGoalRecommendation();
  Future<void> saveGoalRecommendation(String text, DateTime at);
  DateTime? getGoalRecommendedAt();
}

class HiveRunRepository implements RunRepository {
  static const _runsBox = 'runs';
  static const _metaBox = 'meta';
  static const _badgesBox = 'badges';

  late final Box<String> _runs;
  late final Box _meta;
  late final Box<String> _badges;

  static Future<HiveRunRepository> open() async {
    await Hive.initFlutter();
    final repo = HiveRunRepository();
    repo._runs = await Hive.openBox<String>(_runsBox);
    repo._meta = await Hive.openBox(_metaBox);
    repo._badges = await Hive.openBox<String>(_badgesBox);
    return repo;
  }

  @override
  Future<List<RunSession>> getAll() async {
    final list = _runs.values.map(RunSession.decode).toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  @override
  RunSession? getById(String id) {
    final raw = _runs.get(id);
    return raw == null ? null : RunSession.decode(raw);
  }

  @override
  Future<List<RunSession>> upsertAll(List<RunSession> runs) async {
    final added = <RunSession>[];
    for (final run in runs) {
      if (!_runs.containsKey(run.id)) added.add(run);
      await _runs.put(run.id, run.encode());
    }
    return added;
  }

  @override
  Future<void> delete(String id) => _runs.delete(id);

  @override
  Future<void> clear() async {
    await _runs.clear();
    await _badges.clear();
    await _meta.delete('lastSyncedAt');
    await _meta.delete('ignoredIds');
    // AI 요약 캐시도 함께 정리 (geminiApiKey 설정은 기기 설정이므로 유지)
    final summaryKeys =
        _meta.keys.where((k) => k is String && k.startsWith('aiSummary:'));
    await _meta.deleteAll(summaryKeys);
    await _meta.delete('goalRecommendation');
    await _meta.delete('goalRecommendedAt');
  }

  @override
  DateTime? get lastSyncedAt {
    final ms = _meta.get('lastSyncedAt') as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  @override
  Future<void> setLastSyncedAt(DateTime t) =>
      _meta.put('lastSyncedAt', t.millisecondsSinceEpoch);

  @override
  Set<String> getIgnoredIds() {
    final raw = _meta.get('ignoredIds') as String?;
    if (raw == null) return {};
    return (jsonDecode(raw) as List).cast<String>().toSet();
  }

  @override
  Future<void> addIgnoredIds(Iterable<String> ids) {
    final merged = getIgnoredIds()..addAll(ids);
    return _meta.put('ignoredIds', jsonEncode(merged.toList()));
  }

  @override
  Future<void> removeIgnoredIds(Iterable<String> ids) {
    final remain = getIgnoredIds()..removeAll(ids);
    return _meta.put('ignoredIds', jsonEncode(remain.toList()));
  }

  @override
  List<(DateTime, double)> getVo2Series() {
    final raw = _meta.get('vo2Series') as String?;
    if (raw == null) return const [];
    return (jsonDecode(raw) as List)
        .map((e) => (
              DateTime.fromMillisecondsSinceEpoch((e[0] as num).toInt()),
              (e[1] as num).toDouble(),
            ))
        .toList();
  }

  @override
  Future<void> saveVo2Series(List<(DateTime, double)> series) => _meta.put(
        'vo2Series',
        jsonEncode(
            series.map((e) => [e.$1.millisecondsSinceEpoch, e.$2]).toList()),
      );

  @override
  List<EarnedBadge> getEarnedBadges() => _badges.values
      .map((raw) =>
          EarnedBadge.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> badges) async {
    for (final b in badges) {
      await _badges.put(b.badgeId, jsonEncode(b.toJson()));
    }
  }

  @override
  String? getGeminiApiKey() => _meta.get('geminiApiKey') as String?;

  @override
  Future<void> setGeminiApiKey(String? key) => (key == null || key.isEmpty)
      ? _meta.delete('geminiApiKey')
      : _meta.put('geminiApiKey', key);

  @override
  String? getAiSummary(String runId) =>
      _meta.get('aiSummary:$runId') as String?;

  @override
  Future<void> saveAiSummary(String runId, String summary) =>
      _meta.put('aiSummary:$runId', summary);

  @override
  String? getGoalRecommendation() => _meta.get('goalRecommendation') as String?;

  @override
  Future<void> saveGoalRecommendation(String text, DateTime at) =>
      _meta.putAll({
        'goalRecommendation': text,
        'goalRecommendedAt': at.millisecondsSinceEpoch,
      });

  @override
  DateTime? getGoalRecommendedAt() {
    final ms = _meta.get('goalRecommendedAt') as int?;
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }
}
