import 'package:http/http.dart' as http;

import '../logic/stats.dart';
import '../models/run_session.dart';
import 'gemini/gemini_dto.dart';
import 'gemini/gemini_http_client.dart';
import 'gemini/gemini_prompt_builder.dart';

export 'gemini/gemini_dto.dart';
export 'gemini/gemini_http_client.dart'
    show GeminiNotConfiguredException, GeminiHttpEngine;
export 'gemini/gemini_prompt_builder.dart';

/// Gemini API로 러닝 1회를 한국어로 요약·코칭하는 서비스.
/// API 키는 사용자가 설정 화면에서 직접 입력해 기기 로컬(Hive)에만 저장한다 —
/// 코드에 하드코딩하지 않는다 (AGENTS.md 보안 규칙).
class GeminiService {
  final GeminiHttpEngine _engine;

  GeminiService({
    http.Client? client,
    Future<void> Function(Duration)? delay,
  }) : _engine = GeminiHttpEngine(client: client, delay: delay);

  GeminiService.withEngine(this._engine);

  /// [run]을 [recentRuns](같은 러닝 제외, 최근 순 최대 5개)와 비교해 코멘트를 생성한다.
  Future<String> summarizeRun(
    String apiKey,
    RunSession run,
    List<RunSession> recentRuns,
  ) {
    final prompt = buildPrompt(run, recentRuns);
    return _generate(apiKey, prompt);
  }

  /// 최근 러닝 통계를 바탕으로 다음 1~2주의 구체적인 목표를 제안한다.
  Future<String> recommendGoal(
    String apiKey,
    StatsSummary stats,
    MonthlyStats monthly,
    List<RunSession> recentRuns,
  ) {
    final prompt = buildGoalPrompt(stats, monthly, recentRuns);
    return _generate(apiKey, prompt);
  }

  static int? averagePaceSecPerKm(List<RunSession> runs) =>
      GeminiPromptBuilder.averagePaceSecPerKm(runs);

  static String buildPrompt(RunSession run, List<RunSession> recentRuns) =>
      GeminiPromptBuilder.buildRunSummaryPrompt(run, recentRuns);

  static String buildGoalPrompt(
    StatsSummary stats,
    MonthlyStats monthly,
    List<RunSession> recentRuns,
  ) =>
      GeminiPromptBuilder.buildGoalRecommendationPrompt(
        stats,
        monthly,
        recentRuns,
      );

  Future<String> _generate(String apiKey, String prompt) async {
    final request = GeminiGenerateRequestDto.textPrompt(prompt);
    final response = await _engine.generate(
      apiKey: apiKey,
      request: request,
    );
    return response.extractCleanText();
  }
}
