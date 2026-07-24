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
  ) {
    return _generate(apiKey, _buildPrompt(run, recentRuns));
  }

  /// 최근 러닝 통계를 바탕으로 다음 1~2주의 구체적인 목표를 제안한다.
  Future<String> recommendGoal(
    String apiKey,
    StatsSummary stats,
    MonthlyStats monthly,
    List<RunSession> recentRuns,
  ) {
    return _generate(
      apiKey,
      _buildGoalPrompt(stats, monthly, recentRuns),
    );
  }

  Future<String> _generate(String apiKey, String prompt) async {
    if (apiKey.isEmpty) throw const GeminiNotConfiguredException();

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );
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
                  {'text': prompt},
                ],
              },
            ],
            // thinkingConfig는 모델 버전에 따라 지원 여부가 달라 INVALID_ARGUMENT(400)를
            // 유발할 수 있어 요청에 넣지 않는다. 대신 사고 과정 몫까지 감안해 예산을 넉넉히
            // 잡고, 응답 파싱 시 thought:true 파트를 걸러내는 방식으로 대응한다.
            'generationConfig': {'maxOutputTokens': 2048},
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
    // thought:true 파트는 모델의 내부 사고 초안이라 최종 답변이 아님 — 반드시 제외.
    // thinkingBudget:0을 설정해도 모델에 따라 무시될 수 있어 방어적으로 한 번 더 거른다.
    final text = parts
        ?.where((p) => p['thought'] != true)
        .map((p) => p['text'] as String? ?? '')
        .join('')
        .trim();
    if (text == null || text.isEmpty) {
      throw Exception('Gemini 응답이 비어있습니다');
    }
    return text;
  }

  String _buildGoalPrompt(
    StatsSummary stats,
    MonthlyStats monthly,
    List<RunSession> recentRuns,
  ) {
    final currentWeek = StatsSummary.weekStart(DateTime.now());
    final weekStarts = List.generate(
      4,
      (index) => currentWeek.subtract(Duration(days: (3 - index) * 7)),
    );
    final weeklyKm = <DateTime, double>{
      for (final week in weekStarts) week: 0,
    };
    for (final run in recentRuns) {
      final week = StatsSummary.weekStart(run.startTime);
      if (weeklyKm.containsKey(week)) {
        weeklyKm[week] = weeklyKm[week]! + run.distanceKm;
      }
    }

    final best5k = stats.best5kPaceSec == null
        ? '기록 없음'
        : '${fmtPace(stats.best5kPaceSec!)}/km';
    final recentWeeklyKm = weekStarts
        .map((week) => '${weeklyKm[week]!.toStringAsFixed(1)}km')
        .join(' / ');

    final buf = StringBuffer();
    buf.writeln(
      '너는 개인 러닝 코치야. 아래 러닝 이력을 보고 다음 1~2주 목표를 '
      '한국어 2~4문장으로 제안해줘. 무리한 급증 없이 현재 수준에서 약간 '
      '도전적인 수준으로, 구체적 숫자(주 몇 회, 총 몇 km, 목표 페이스나 거리)를 '
      '포함해줘. 이모지나 과장 없이 담백하게 써줘.',
    );
    buf.writeln();
    buf.writeln('[러닝 이력]');
    buf.writeln(
      '- 누적: ${stats.totalRuns}회, ${stats.totalKm.toStringAsFixed(1)}km',
    );
    buf.writeln('- 주 3회 스트릭: ${stats.currentStreakWeeks}주');
    buf.writeln('- 최장 거리: ${stats.longestRunKm.toStringAsFixed(1)}km');
    buf.writeln('- 최고 5km 페이스: $best5k');
    buf.writeln('- 이번 달 거리: ${monthly.thisMonthKm.toStringAsFixed(1)}km');
    buf.writeln('- 지난달 거리: ${monthly.lastMonthKm.toStringAsFixed(1)}km');
    buf.writeln('- 최근 4주 주간 거리(오래된 순): $recentWeeklyKm');
    return buf.toString();
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
