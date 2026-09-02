import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  // latest alias는 새 릴리스마다 뒤에서 교체될 수 있어 운영용 모델을 고정한다.
  static const _model = 'gemini-3.6-flash';
  static const _maxAttempts = 3;
  static const _retryableStatusCodes = {429, 500, 502, 503, 504};

  /// [run]을 [recentRuns](같은 러닝 제외, 최근 순 최대 5개)와 비교해 코멘트를 생성한다.
  Future<String> summarizeRun(
    String apiKey,
    RunSession run,
    List<RunSession> recentRuns,
  ) {
    return _generate(apiKey, buildPrompt(run, recentRuns));
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
      buildGoalPrompt(stats, monthly, recentRuns),
    );
  }

  static int? averagePaceSecPerKm(List<RunSession> runs) {
    final validPaces = runs
        .map((r) => r.avgPaceSecPerKm)
        .where((pace) => pace > 0)
        .toList();
    if (validPaces.isEmpty) return null;
    return (validPaces.reduce((a, b) => a + b) / validPaces.length).round();
  }

  Future<String> _generate(String apiKey, String prompt) async {
    if (apiKey.isEmpty) throw const GeminiNotConfiguredException();

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent',
    );
    final body = jsonEncode({
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
    });

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final res = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: body,
            )
            .timeout(const Duration(seconds: 60));

        if (res.statusCode == 200) {
          return _parseResponse(res);
        }

        final canRetry = _retryableStatusCodes.contains(res.statusCode);
        if (!canRetry || attempt == _maxAttempts) {
          if (res.statusCode == 503) {
            throw Exception('Gemini 서버가 일시적으로 혼잡합니다. 잠시 후 다시 시도하세요.');
          }
          throw Exception('Gemini 요청 실패 (${res.statusCode}): ${res.body}');
        }
      } on TimeoutException {
        if (attempt == _maxAttempts) {
          throw Exception('Gemini 응답 시간 초과 (60초). 잠시 후 다시 시도해주세요.');
        }
      } on SocketException catch (e) {
        if (attempt == _maxAttempts) {
          throw Exception('네트워크 연결 오류: ${e.message}');
        }
      } on http.ClientException catch (e) {
        if (attempt == _maxAttempts) {
          throw Exception('네트워크 요청 실패: ${e.message}');
        }
      }

      // 503/429 또는 일시적 네트워크 오류 시 1초, 2초 간격으로 재시도한다.
      await Future<void>.delayed(Duration(seconds: attempt));
    }
    throw StateError('Gemini 요청 재시도 흐름이 비정상적으로 종료되었습니다');
  }

  String _parseResponse(http.Response res) {
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

  static String buildGoalPrompt(
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
    final weeklyRuns = <DateTime, int>{
      for (final week in weekStarts) week: 0,
    };
    for (final run in recentRuns) {
      final week = StatsSummary.weekStart(run.startTime);
      if (weeklyKm.containsKey(week)) {
        weeklyKm[week] = weeklyKm[week]! + run.distanceKm;
        weeklyRuns[week] = weeklyRuns[week]! + 1;
      }
    }

    final best1k = stats.best1kPaceSec == null
        ? '기록 없음'
        : '${fmtPace(stats.best1kPaceSec!)}/km';
    final best5k = stats.best5kPaceSec == null
        ? '기록 없음'
        : '${fmtPace(stats.best5kPaceSec!)}/km';
    final recentWeeklyKm = weekStarts
        .map((week) =>
            '${weeklyKm[week]!.toStringAsFixed(1)}km(${weeklyRuns[week]}회)')
        .join(' / ');

    final thisMonthPace = monthly.thisMonthAvgPaceSec != null
        ? '${fmtPace(monthly.thisMonthAvgPaceSec!)}/km'
        : '기록 없음';
    final lastMonthPace = monthly.lastMonthAvgPaceSec != null
        ? '${fmtPace(monthly.lastMonthAvgPaceSec!)}/km'
        : '기록 없음';

    final recentPace = averagePaceSecPerKm(recentRuns.take(5).toList());
    final recentAvgPaceStr =
        recentPace != null ? '${fmtPace(recentPace)}/km' : '기록 없음';

    final buf = StringBuffer();
    buf.writeln(
      '너는 전문 개인 러닝 코치야. 아래 러너의 누적 통계, 월간/주간 추세, 최근 러닝 기록을 심층 분석해서 다음 1~2주간 실천할 맞춤형 목표와 훈련 계획을 제안해줘.',
    );
    buf.writeln(
      '급격한 마일리지 증가로 인한 부상을 방지하고(주간 거리 10% 이내 증편 원칙), 현재 체력 수준에 맞춰 달성 가능하면서도 동기부여가 되는 계획을 세워줘.',
    );
    buf.writeln(
      '이모지나 과장 없이, 명확하고 논리적인 톤으로 아래 3가지 섹션 형식에 맞춰 작성해줘:',
    );
    buf.writeln();
    buf.writeln('🎯 [다음 1~2주 목표]');
    buf.writeln('- 주당 러닝 빈도 및 주간 목표 총 거리 (예: 주 3회, 주간 15~18km)');
    buf.writeln('- 목표 단일 세션 거리 및 목표 페이스 기준');
    buf.writeln();
    buf.writeln('🏃 [추천 세션 구성]');
    buf.writeln('- 회복/이지런, 템포/지속주, 롱런(LSD) 등 주간 2~3회 러닝의 구체적인 세션별 분배 가이드');
    buf.writeln();
    buf.writeln('💡 [코칭 포인트 & 주의사항]');
    buf.writeln('- 심박 관리(Z2/Z3 영역 비중), 페이스 조절, 부상 예방 및 회복에 대한 핵심 조언 1~2개');
    buf.writeln();
    buf.writeln('---');
    buf.writeln('[러닝 이력 및 통계]');
    buf.writeln(
      '- 전체 누적: ${stats.totalRuns}회 / ${stats.totalKm.toStringAsFixed(1)}km',
    );
    buf.writeln(
      '- 주 3회 연속 달성(스트릭): ${stats.currentStreakWeeks}주 (최다 주간 거리 ${stats.maxWeekKm.toStringAsFixed(1)}km)',
    );
    buf.writeln('- 최장 거리(1회): ${stats.longestRunKm.toStringAsFixed(1)}km');
    buf.writeln('- 개인 최고 페이스: 1km $best1k / 5km $best5k');
    buf.writeln('- 최근 5회 평균 페이스: $recentAvgPaceStr');
    buf.writeln(
      '- 이번 달: ${monthly.thisMonthKm.toStringAsFixed(1)}km (${monthly.thisMonthRuns}회, 평균 페이스 $thisMonthPace)',
    );
    buf.writeln(
      '- 지난달: ${monthly.lastMonthKm.toStringAsFixed(1)}km (${monthly.lastMonthRuns}회, 평균 페이스 $lastMonthPace)',
    );
    buf.writeln('- 최근 4주 주간 실적(오래된 순): $recentWeeklyKm');
    return buf.toString();
  }

  static String buildPrompt(RunSession run, List<RunSession> recentRuns) {
    final buf = StringBuffer();
    buf.writeln('너는 전문 개인 러닝 코치야. 아래 러닝 기록 데이터를 심층 분석해서 한국어로 전문적이고 실용적인 코칭 피드백을 작성해줘.');
    buf.writeln('이모지나 과장된 감탄사 없이, 명확하고 논리적인 톤으로 아래 3가지 섹션 형식에 맞춰 작성해줘:');
    buf.writeln();
    buf.writeln('📌 [핵심 요약]');
    buf.writeln('- 이번 러닝의 총평과 주요 성과 요약 (1~2문장)');
    buf.writeln();
    buf.writeln('📊 [페이스 & 심박 분석]');
    buf.writeln('- 구간별 페이스(스플릿) 변화와 페이스 배분(이븐/네거티브/포지티브 스플릿) 분석');
    buf.writeln('- 심박수 및 심박존(유산소/지구력/역치) 분포를 바탕으로 한 심폐 효율 및 체력 부하 분석');
    buf.writeln('- 최근 러닝 평균과의 비교 및 성장 포인트');
    buf.writeln();
    buf.writeln('💡 [맞춤 코칭 팁]');
    buf.writeln('- 이번 러닝 데이터를 기반으로 한 다음 훈련 조언 (회복런, 심박존 관리, 케이던스/자세, 다음 목표 거리/페이스 제안 등 실천 가능한 구체적 팁 1~2개)');
    buf.writeln();
    buf.writeln('---');
    buf.writeln('[이번 러닝 데이터]');
    buf.writeln('- 거리: ${run.distanceKm.toStringAsFixed(2)}km');
    buf.writeln('- 소요 시간: ${fmtDuration(run.durationSec)}');
    buf.writeln('- 평균 페이스: ${fmtPace(run.avgPaceSecPerKm)}/km');
    if (run.avgHr != null) buf.writeln('- 평균 심박수: ${run.avgHr!.round()}bpm');
    if (run.maxHr != null) buf.writeln('- 최고 심박수: ${run.maxHr!.round()}bpm');
    if (run.calories != null) buf.writeln('- 소모 칼로리: ${run.calories!.round()}kcal');
    if (run.steps != null && run.steps! > 0 && run.durationSec > 0) {
      final spm = (run.steps! / (run.durationSec / 60)).round();
      buf.writeln('- 총 걸음수: ${run.steps}걸음 (평균 케이던스: ${spm}spm)');
    }
    if (run.elevationM != null && run.elevationM! > 0) {
      buf.writeln('- 획득 고도: ${run.elevationM!.toStringAsFixed(1)}m');
    }
    final hour = run.startTime.hour;
    buf.writeln('- 러닝 시간대: ${run.startTime.hour}시 (${hour >= 21 || hour < 4 ? '야간' : hour < 8 ? '새벽' : '주간'} 러닝)');

    // 스플릿 데이터
    if (run.splits.isNotEmpty) {
      buf.writeln();
      buf.writeln('[1km 구간별 스플릿]');
      for (final s in run.splits) {
        final kmLabel = s.km == s.km.toInt()
            ? '${s.km.toInt()}km'
            : '${s.km.toStringAsFixed(2)}km';
        final hrText =
            s.avgHr != null ? ' (평균 ${s.avgHr!.round()}bpm)' : '';
        buf.writeln('- $kmLabel: ${fmtPace(s.paceSecPerKm)}/km$hrText');
      }
    }

    // 심박존 데이터
    if (run.hrSeries.isNotEmpty) {
      final zones = hrZoneDistribution(run.hrSeries);
      final zLabels = [
        'Z1(회복 <60%)',
        'Z2(지구력 60~70%)',
        'Z3(템포 70~80%)',
        'Z4(역치 80~90%)',
        'Z5(무산소 90%+)'
      ];
      final zoneDetails = <String>[];
      for (var i = 0; i < zones.length; i++) {
        final pct = (zones[i] * 100).round();
        if (pct > 0) {
          zoneDetails.add('${zLabels[i]}: $pct%');
        }
      }
      if (zoneDetails.isNotEmpty) {
        buf.writeln();
        buf.writeln('[심박존 분포]');
        buf.writeln('- ${zoneDetails.join(', ')}');
      }
    }

    // 최근 러닝 평균
    if (recentRuns.isNotEmpty) {
      final avgKm = recentRuns.fold<double>(0, (a, r) => a + r.distanceKm) /
          recentRuns.length;
      final avgPace = averagePaceSecPerKm(recentRuns);
      final validHrs =
          recentRuns.map((r) => r.avgHr).whereType<double>().toList();
      final avgHr = validHrs.isNotEmpty
          ? (validHrs.reduce((a, b) => a + b) / validHrs.length).round()
          : null;

      buf.writeln();
      buf.writeln('[최근 ${recentRuns.length}회 러닝 평균 — 비교용]');
      buf.writeln('- 평균 거리: ${avgKm.toStringAsFixed(2)}km');
      if (avgPace != null) {
        buf.writeln('- 평균 페이스: ${fmtPace(avgPace)}/km');
      }
      if (avgHr != null) {
        buf.writeln('- 평균 심박수: ${avgHr}bpm');
      }
    }

    return buf.toString();
  }
}
