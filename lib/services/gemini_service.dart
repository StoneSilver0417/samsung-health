import 'dart:convert';

import 'package:http/http.dart' as http;

import '../logic/stats.dart';
import '../models/run_session.dart';

class GeminiNotConfiguredException implements Exception {
  const GeminiNotConfiguredException();
  @override
  String toString() => 'Gemini API 키가 설정되지 않았습니다';
}

/// Gemini API로 러닝 1회를 한국어로 요약·코칭하는 서비스.
/// API 키는 사용자가 설정 화면에서 직접 입력해 기기 로컬(Hive)에만 저장한다 —
/// 코드에 하드코딩하지 않는다 (AGENTS.md 보안 규칙).
class GeminiService {
  static const _model = 'gemini-flash-latest';

  /// [run]을 [recentRuns](같은 러닝 제외, 최근 순 최대 5개)와 비교해 코멘트를 생성한다.
  Future<String> summarizeRun(
    String apiKey,
    RunSession run,
    List<RunSession> recentRuns,
  ) async {
    if (apiKey.isEmpty) throw const GeminiNotConfiguredException();

    final prompt = _buildPrompt(run, recentRuns);
    final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent');
    final res = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            // thinkingBudget: 0 — 짧은 요약 작업이라 사고 과정이 불필요.
            // 켜두면 사고 토큰이 maxOutputTokens를 먼저 소모해 답변이 중간에 잘림.
            'generationConfig': {
              'maxOutputTokens': 500,
              'thinkingConfig': {'thinkingBudget': 0},
            },
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (res.statusCode != 200) {
      throw Exception('Gemini 요청 실패 (${res.statusCode}): ${res.body}');
    }
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini 응답에 결과가 없습니다');
    }
    final parts =
        (candidates.first['content'] as Map<String, dynamic>?)?['parts']
            as List?;
    final text = parts?.map((p) => p['text'] as String? ?? '').join('').trim();
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답이 비어있습니다');
    }
    return text;
  }

  String _buildPrompt(RunSession run, List<RunSession> recentRuns) {
    final buf = StringBuffer();
    buf.writeln('너는 개인 러닝 코치야. 아래 러닝 기록을 보고 한국어로 2~4문장의 짧은 요약과 코멘트를 작성해줘. '
        '숫자는 자연스럽게 문장에 녹이고, 과장된 칭찬이나 이모지 없이 담백하게 써줘.');
    buf.writeln();
    buf.writeln('[이번 러닝]');
    buf.writeln('- 거리: ${run.distanceKm.toStringAsFixed(2)}km');
    buf.writeln('- 시간: ${fmtDuration(run.durationSec)}');
    buf.writeln('- 평균 페이스: ${fmtPace(run.avgPaceSecPerKm)}/km');
    if (run.avgHr != null) buf.writeln('- 평균 심박수: ${run.avgHr!.round()}bpm');
    if (run.maxHr != null) buf.writeln('- 최고 심박수: ${run.maxHr!.round()}bpm');
    if (run.calories != null) {
      buf.writeln('- 칼로리: ${run.calories!.round()}kcal');
    }
    final hour = run.startTime.hour;
    buf.writeln('- 시각: ${run.startTime.hour}시 (${hour >= 21 || hour < 4 ? '야간' : hour < 8 ? '새벽' : '주간'} 러닝)');

    if (recentRuns.isNotEmpty) {
      final avgPace = recentRuns
              .where((r) => r.avgPaceSecPerKm > 0)
              .map((r) => r.avgPaceSecPerKm)
              .fold<int>(0, (a, b) => a + b) /
          recentRuns.length;
      final avgKm =
          recentRuns.fold<double>(0, (a, r) => a + r.distanceKm) /
              recentRuns.length;
      buf.writeln();
      buf.writeln('[최근 ${recentRuns.length}회 평균 — 비교 참고용]');
      buf.writeln('- 평균 거리: ${avgKm.toStringAsFixed(2)}km');
      buf.writeln('- 평균 페이스: ${fmtPace(avgPace.round())}/km');
    }
    return buf.toString();
  }
}
