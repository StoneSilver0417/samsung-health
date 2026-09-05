import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/run_session.dart';

/// 러닝 기록(runs), VO2max(vo2maxSeries), 동기화 제외 ID(ignoredIds), 동기화 시간 전담 Store
abstract class RunStore {
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
}

/// Hive 기반 RunStore 구현체
class HiveRunStore implements RunStore {
  final Box<String> _runs;
  final Box _meta;

  HiveRunStore(this._runs, this._meta);

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
    await _meta.delete('lastSyncedAt');
    await _meta.delete('ignoredIds');
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
}
