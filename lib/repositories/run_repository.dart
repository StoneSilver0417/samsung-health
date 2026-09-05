import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/achievement.dart';
import '../models/run_session.dart';
import 'stores/achievement_store.dart';
import 'stores/run_store.dart';
import 'stores/settings_store.dart';

export 'stores/achievement_store.dart';
export 'stores/run_store.dart';
export 'stores/settings_store.dart';

/// 저장소 추상화 및 파사드(Facade).
/// 개별 도메인별 세분화된 Store(RunStore, AchievementStore, SettingsStore)를 코디네이션하며
/// 기존 클라이언트 코드와의 100% 하위 호환성을 제공합니다.
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

  /// Gemini API 키 (Android Keystore 기반 secure storage에 저장)
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

/// Hive 및 FlutterSecureStorage 기반 RunRepository 파사드 구현체.
class HiveRunRepository implements RunRepository {
  static const _runsBox = 'runs.v2';
  static const _metaBox = 'meta.v2';
  static const _badgesBox = 'badges.v2';
  static const _legacyRunsBox = 'runs';
  static const _legacyMetaBox = 'meta';
  static const _legacyBadgesBox = 'badges';
  static const _hiveKeyStorageKey = 'runlog.hive.encryption-key';
  static const _apiKeyStorageKey = 'runlog.gemini.api-key';
  static const _migrationStorageKey = 'runlog.hive.migration-v2';

  final RunStore _runStore;
  final AchievementStore _achievementStore;
  final SettingsStore _settingsStore;

  HiveRunRepository({
    required RunStore runStore,
    required AchievementStore achievementStore,
    required SettingsStore settingsStore,
  })  : _runStore = runStore,
        _achievementStore = achievementStore,
        _settingsStore = settingsStore;

  RunStore get runStore => _runStore;
  AchievementStore get achievementStore => _achievementStore;
  SettingsStore get settingsStore => _settingsStore;

  static List<int> decodeEncryptionKey(String encoded) {
    late final List<int> key;
    try {
      key = base64Url.decode(encoded);
    } on FormatException {
      throw StateError('저장소 암호화 키 형식이 올바르지 않습니다');
    }
    if (key.length != 32) {
      throw StateError('저장소 암호화 키 길이가 올바르지 않습니다');
    }
    return key;
  }

  static String _newEncryptionKey() => base64UrlEncode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );

  static Future<HiveRunRepository> open() async {
    await Hive.initFlutter();
    final secureStorage = FlutterSecureStorage();
    final storedKey = await secureStorage.read(key: _hiveKeyStorageKey);
    final encodedKey = storedKey ?? _newEncryptionKey();
    final encryptionKey = decodeEncryptionKey(encodedKey);
    if (storedKey == null) {
      await secureStorage.write(key: _hiveKeyStorageKey, value: encodedKey);
      if (await secureStorage.read(key: _hiveKeyStorageKey) != encodedKey) {
        throw StateError('저장소 암호화 키를 안전하게 저장하지 못했습니다');
      }
    }

    final cipher = HiveAesCipher(encryptionKey);
    final runs = await Hive.openBox<String>(
      _runsBox,
      encryptionCipher: cipher,
    );
    final meta = await Hive.openBox(_metaBox, encryptionCipher: cipher);
    final badges = await Hive.openBox<String>(
      _badgesBox,
      encryptionCipher: cipher,
    );

    if (await secureStorage.read(key: _migrationStorageKey) != '1') {
      final legacyRuns = await Hive.openBox<String>(_legacyRunsBox);
      final legacyMeta = await Hive.openBox(_legacyMetaBox);
      final legacyBadges = await Hive.openBox<String>(_legacyBadgesBox);
      final legacyApiKey = legacyMeta.get('geminiApiKey');
      try {
        for (final key in legacyRuns.keys) {
          if (key is! String) continue;
          final value = legacyRuns.get(key);
          if (value != null) await runs.put(key, value);
        }
        for (final key in legacyMeta.keys) {
          if (key == 'geminiApiKey') continue;
          final value = legacyMeta.get(key);
          if (value != null) await meta.put(key, value);
        }
        for (final key in legacyBadges.keys) {
          if (key is! String) continue;
          final value = legacyBadges.get(key);
          if (value != null) await badges.put(key, value);
        }

        final secureApiKey = await secureStorage.read(key: _apiKeyStorageKey);
        if (secureApiKey == null &&
            legacyApiKey is String &&
            legacyApiKey.isNotEmpty) {
          await secureStorage.write(
            key: _apiKeyStorageKey,
            value: legacyApiKey,
          );
          if (await secureStorage.read(key: _apiKeyStorageKey) != legacyApiKey) {
            throw StateError('Gemini API 키를 안전하게 마이그레이션하지 못했습니다');
          }
        }
      } finally {
        await legacyRuns.close();
        await legacyMeta.close();
        await legacyBadges.close();
      }
      await Hive.deleteBoxFromDisk(_legacyRunsBox);
      await Hive.deleteBoxFromDisk(_legacyMetaBox);
      await Hive.deleteBoxFromDisk(_legacyBadgesBox);
      await secureStorage.write(key: _migrationStorageKey, value: '1');
    }

    final geminiApiKey = await secureStorage.read(key: _apiKeyStorageKey);
    final runStore = HiveRunStore(runs, meta);
    final achievementStore = HiveAchievementStore(badges);
    final settingsStore = HiveSettingsStore(
      meta,
      secureStorage,
      initialApiKey: geminiApiKey,
    );

    return HiveRunRepository(
      runStore: runStore,
      achievementStore: achievementStore,
      settingsStore: settingsStore,
    );
  }

  // === RunStore Delegation ===

  @override
  Future<List<RunSession>> getAll() => _runStore.getAll();

  @override
  RunSession? getById(String id) => _runStore.getById(id);

  @override
  Future<List<RunSession>> upsertAll(List<RunSession> runs) =>
      _runStore.upsertAll(runs);

  @override
  Future<void> delete(String id) => _runStore.delete(id);

  @override
  DateTime? get lastSyncedAt => _runStore.lastSyncedAt;

  @override
  Future<void> setLastSyncedAt(DateTime t) => _runStore.setLastSyncedAt(t);

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

  // === AchievementStore Delegation ===

  @override
  List<EarnedBadge> getEarnedBadges() => _achievementStore.getEarnedBadges();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> badges) =>
      _achievementStore.saveEarnedBadges(badges);

  // === SettingsStore Delegation ===

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

  // === Coordinated Clear ===

  @override
  Future<void> clear() async {
    await _runStore.clear();
    await _achievementStore.clear();
    await _settingsStore.clearCache();
  }
}
