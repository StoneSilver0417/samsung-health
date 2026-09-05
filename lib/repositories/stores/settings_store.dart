import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Gemini API 키(apiKey), AI 요약 캐시(aiSummaries), AI 목표 추천 캐시 전담 Store
abstract class SettingsStore {
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

  /// AI 캐시 데이터 정리 (API 키 등 기기 설정은 유지)
  Future<void> clearCache();
}

/// Hive & FlutterSecureStorage 기반 SettingsStore 구현체
class HiveSettingsStore implements SettingsStore {
  static const _apiKeyStorageKey = 'runlog.gemini.api-key';

  final Box _meta;
  final FlutterSecureStorage _secureStorage;
  String? _geminiApiKey;

  HiveSettingsStore(this._meta, this._secureStorage, {String? initialApiKey})
      : _geminiApiKey = initialApiKey;

  @override
  String? getGeminiApiKey() => _geminiApiKey;

  @override
  Future<void> setGeminiApiKey(String? key) async {
    final normalized = key?.trim();
    if (normalized == null || normalized.isEmpty) {
      await _secureStorage.delete(key: _apiKeyStorageKey);
      _geminiApiKey = null;
      return;
    }
    await _secureStorage.write(
      key: _apiKeyStorageKey,
      value: normalized,
    );
    _geminiApiKey = normalized;
  }

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

  @override
  Future<void> clearCache() async {
    final summaryKeys =
        _meta.keys.where((k) => k is String && k.startsWith('aiSummary:'));
    await _meta.deleteAll(summaryKeys);
    await _meta.delete('goalRecommendation');
    await _meta.delete('goalRecommendedAt');
  }
}
