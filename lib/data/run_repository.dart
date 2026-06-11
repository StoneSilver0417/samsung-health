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

  List<EarnedBadge> getEarnedBadges();
  Future<void> saveEarnedBadges(List<EarnedBadge> badges);
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
}
