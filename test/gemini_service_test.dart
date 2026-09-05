import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/gemini_service.dart';

RunSession _run({
  required double km,
  required int durationSec,
  DateTime? startTime,
  double? avgHr,
  double? maxHr,
  int? steps,
  double? elevationM,
  double? calories,
  List<Split> splits = const [],
  List<RunLap> laps = const [],
  List<HrSample> hrSeries = const [],
}) =>
    RunSession(
      id: '$km-$durationSec',
      startTime: startTime ?? DateTime(2026, 8, 1, 21),
      endTime: (startTime ?? DateTime(2026, 8, 1, 21))
          .add(Duration(seconds: durationSec)),
      distanceM: km * 1000,
      durationSec: durationSec,
      avgHr: avgHr,
      maxHr: maxHr,
      steps: steps,
      elevationM: elevationM,
      calories: calories,
      splits: splits,
      laps: laps,
      hrSeries: hrSeries,
    );

http.Response _utf8Response(String body, [int statusCode = 200]) {
  return http.Response.bytes(
    utf8.encode(body),
    statusCode,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

void main() {
  group('GeminiNotConfiguredException', () {
    test('provides a user-friendly error string', () {
      const ex = GeminiNotConfiguredException();
      expect(ex.toString(), 'Gemini API 키가 설정되지 않았습니다');
    });

    test('throws GeminiNotConfiguredException when apiKey is empty', () async {
      final service = GeminiService();
      final run = _run(km: 5, durationSec: 1800);

      expect(
        () => service.summarizeRun('', run, []),
        throwsA(isA<GeminiNotConfiguredException>()),
      );
      expect(
        () => service.recommendGoal(
          '',
        const StatsSummary(
          weekKm: 0,
          weekRuns: 0,
          weekSec: 0,
          totalKm: 0,
          totalRuns: 0,
          totalSec: 0,
          currentStreakWeeks: 0,
          longestRunKm: 0,
          best1kPaceSec: null,
          best5kPaceSec: null,
          maxWeekKm: 0,
        ),
          MonthlyStats.fromRuns([]),
          [],
        ),
        throwsA(isA<GeminiNotConfiguredException>()),
      );
    });
  });

  group('GeminiService API Calls and Response Parsing', () {
    test('summarizeRun sends correct headers, payload, and parses valid response',
        () async {
      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        final responseBody = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '훌륭한 5km 야간 러닝이었습니다.'},
                ],
              },
            },
          ],
        });
        return http.Response(responseBody, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final service = GeminiService(client: mockClient);
      final run = _run(km: 5.0, durationSec: 1800, avgHr: 145);
      final result = await service.summarizeRun('test-api-key', run, []);

      expect(result, '훌륭한 5km 야간 러닝이었습니다.');
      expect(
        capturedRequest.url.toString(),
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.6-flash:generateContent',
      );
      expect(capturedRequest.headers['x-goog-api-key'], 'test-api-key');
      expect(capturedRequest.headers['Content-Type'], 'application/json');

      final body = jsonDecode(capturedRequest.body) as Map<String, dynamic>;
      expect(body['generationConfig']['maxOutputTokens'], 2048);
      expect(body['contents'][0]['parts'][0]['text'], contains('5.00km'));
    });

    test('recommendGoal sends goal prompt and returns parsed text', () async {
      final mockClient = MockClient((request) async {
        final responseBody = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': '다음 1~2주간 주 3회 15km를 목표로 설정해보세요.'},
                ],
              },
            },
          ],
        });
        return _utf8Response(responseBody);
      });

      final service = GeminiService(client: mockClient);
      const stats = StatsSummary(
        weekKm: 10,
        weekRuns: 2,
        weekSec: 3600,
        totalKm: 50,
        totalRuns: 10,
        totalSec: 18000,
        currentStreakWeeks: 2,
        longestRunKm: 8,
        best1kPaceSec: null,
        best5kPaceSec: null,
        maxWeekKm: 20,
      );
      final monthly = MonthlyStats.fromRuns([]);
      final result = await service.recommendGoal(
        'test-key',
        stats,
        monthly,
        [],
      );

      expect(result, '다음 1~2주간 주 3회 15km를 목표로 설정해보세요.');
    });

    test('filters out internal thought parts (thought: true) from response',
        () async {
      final mockClient = MockClient((request) async {
        final responseBody = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': '*Drafting thoughts about heart rate zones...',
                    'thought': true,
                  },
                  {'text': '핵심 요약: 페이스 조절이 매우 안정적이었습니다.'},
                  {
                    'text': '*More thinking notes...',
                    'thought': true,
                  },
                  {'text': ' 코칭 팁: 후반 1km에서 케이던스를 올려보세요.'},
                ],
              },
            },
          ],
        });
        return _utf8Response(responseBody);
      });

      final service = GeminiService(client: mockClient);
      final run = _run(km: 5.0, durationSec: 1800);
      final result = await service.summarizeRun('key', run, []);

      expect(
        result,
        '핵심 요약: 페이스 조절이 매우 안정적이었습니다. 코칭 팁: 후반 1km에서 케이던스를 올려보세요.',
      );
      expect(result, isNot(contains('Drafting thoughts')));
      expect(result, isNot(contains('More thinking notes')));
    });

    test('throws Exception when candidates list is null or empty', () async {
      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode({'candidates': []}), 200);
      });

      final service = GeminiService(client: mockClient);
      final run = _run(km: 5.0, durationSec: 1800);

      expect(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 응답에 결과가 없습니다'),
        )),
      );
    });

    test('throws Exception when response text after filtering thoughts is empty',
        () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '   '},
                    {'text': 'Only thoughts', 'thought': true},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = GeminiService(client: mockClient);
      final run = _run(km: 5.0, durationSec: 1800);

      expect(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 응답이 비어있습니다'),
        )),
      );
    });
  });

  group('HTTP Status Code Handling, Backoff, and Retry Flow', () {
    test('non-retryable status code (400) fails immediately without retrying',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        return http.Response('{"error": "INVALID_ARGUMENT"}', 400);
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 요청 실패 (400)'),
        )),
      );

      expect(attempts, 1);
      expect(delays, isEmpty);
    });

    test('recovers on 2nd attempt when 1st attempt returns 503 Service Unavailable',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response('Service Unavailable', 503);
        }
        return _utf8Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '성공적으로 생성된 요약입니다.'},
                  ],
                },
              },
            ],
          }),
        );
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);
      final result = await service.summarizeRun('key', run, []);

      expect(result, '성공적으로 생성된 요약입니다.');
      expect(attempts, 2);
      expect(delays, [const Duration(seconds: 1)]);
    });

    test('retries 3 times on persistent 503 and throws friendly error message',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        return http.Response('Service Unavailable', 503);
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 서버가 일시적으로 혼잡합니다. 잠시 후 다시 시도하세요.'),
        )),
      );

      expect(attempts, 3);
      expect(delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });

    test('retries 3 times on 429 Too Many Requests and throws status failure',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        return http.Response('Quota Exceeded', 429);
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 요청 실패 (429): Quota Exceeded'),
        )),
      );

      expect(attempts, 3);
      expect(delays, [
        const Duration(seconds: 1),
        const Duration(seconds: 2),
      ]);
    });
  });

  group('Network Exceptions and Timeout Handling', () {
    test('retries on TimeoutException and throws 60s timeout error on 3rd failure',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        throw TimeoutException('timed out');
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Gemini 응답 시간 초과 (60초). 잠시 후 다시 시도해주세요.'),
        )),
      );

      expect(attempts, 3);
      expect(delays.length, 2);
    });

    test('retries on SocketException and throws network connection error on 3rd failure',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        throw const SocketException('Connection refused');
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('네트워크 연결 오류: Connection refused'),
        )),
      );

      expect(attempts, 3);
      expect(delays.length, 2);
    });

    test('retries on http.ClientException and throws request failure on 3rd failure',
        () async {
      var attempts = 0;
      final delays = <Duration>[];

      final mockClient = MockClient((request) async {
        attempts++;
        throw http.ClientException('Network pipe broken');
      });

      final service = GeminiService(
        client: mockClient,
        delay: (d) async => delays.add(d),
      );
      final run = _run(km: 5.0, durationSec: 1800);

      await expectLater(
        () => service.summarizeRun('key', run, []),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('네트워크 요청 실패: Network pipe broken'),
        )),
      );

      expect(attempts, 3);
      expect(delays.length, 2);
    });

    test('recovers from SocketException on 1st attempt when 2nd attempt succeeds',
        () async {
      var attempts = 0;

      final mockClient = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          throw const SocketException('Temporary wifi glitch');
        }
        return _utf8Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '복구 성공'},
                  ],
                },
              },
            ],
          }),
        );
      });

      final service = GeminiService(
        client: mockClient,
        delay: (_) async {},
      );
      final run = _run(km: 5.0, durationSec: 1800);
      final result = await service.summarizeRun('key', run, []);

      expect(result, '복구 성공');
      expect(attempts, 2);
    });
  });

  group('Prompt Generation and Formatting Edge Cases', () {
    test('average pace uses only runs with a valid pace', () {
      final average = GeminiService.averagePaceSecPerKm([
        _run(km: 5, durationSec: 1500),
        _run(km: 0, durationSec: 600),
        _run(km: 5, durationSec: 1800),
      ]);

      expect(average, 330);
    });

    test('average pace is absent when every run has no valid pace', () {
      expect(
        GeminiService.averagePaceSecPerKm([_run(km: 0, durationSec: 600)]),
        isNull,
      );
    });

    test('buildPrompt includes structured coaching sections', () {
      final run = _run(km: 5.0, durationSec: 1800, avgHr: 150, maxHr: 168);
      final prompt = GeminiService.buildPrompt(run, []);

      expect(prompt, contains('[핵심 요약]'));
      expect(prompt, contains('[페이스 & 심박 분석]'));
      expect(prompt, contains('[맞춤 코칭 팁]'));
      expect(prompt, contains('5.00km'));
      expect(prompt, contains('150bpm'));
      expect(prompt, contains('168bpm'));
    });

    test('buildPrompt formats splits, hr zones, cadence, and recent averages', () {
      final run = _run(
        km: 3.0,
        durationSec: 1080,
        avgHr: 145,
        steps: 2880,
        elevationM: 15.5,
        calories: 220,
        splits: [
          const Split(km: 1.0, paceSecPerKm: 360, avgHr: 140),
          const Split(km: 2.0, paceSecPerKm: 355, avgHr: 145),
          const Split(km: 3.0, paceSecPerKm: 365, avgHr: 150),
        ],
        hrSeries: [
          HrSample(time: DateTime(2026, 8, 1, 21, 5), bpm: 120),
          HrSample(time: DateTime(2026, 8, 1, 21, 10), bpm: 145),
          HrSample(time: DateTime(2026, 8, 1, 21, 15), bpm: 160),
        ],
      );

      final recent = [
        _run(km: 5.0, durationSec: 1800, avgHr: 150),
        _run(km: 4.0, durationSec: 1440, avgHr: 146),
      ];

      final prompt = GeminiService.buildPrompt(run, recent);

      // Splits
      expect(prompt, contains('[구간별 스플릿]'));
      expect(prompt, contains('1km: 6\'00"/km (평균 140bpm)'));
      expect(prompt, contains('2km: 5\'55"/km (평균 145bpm)'));

      // Stride & Dynamics
      expect(prompt, contains('평균 보폭: 104cm'));
      expect(prompt, contains('훈련 부하(TRIMP)'));
      expect(prompt, contains('소모 칼로리: 220kcal'));

      // Cadence & Elevation
      expect(prompt, contains('160spm'));
      expect(prompt, contains('15.5m'));

      // HR Zones
      expect(prompt, contains('[심박존 분포]'));

      // Recent averages
      expect(prompt, contains('[최근 2회 러닝 평균 — 비교용]'));
      expect(prompt, contains('4.50km'));
      expect(prompt, contains('6\'00"/km'));
      expect(prompt, contains('148bpm'));
    });

    test('buildPrompt uses watch laps instead of splits when laps are present',
        () async {
      final run = _run(
        km: 2.0,
        durationSec: 720,
        laps: [
          RunLap(
            lapNumber: 1,
            startTime: DateTime(2026, 8, 1, 21),
            endTime: DateTime(2026, 8, 1, 21, 6),
            distanceM: 1000,
            avgHr: 142,
          ),
          RunLap(
            lapNumber: 2,
            startTime: DateTime(2026, 8, 1, 21, 6),
            endTime: DateTime(2026, 8, 1, 21, 12),
            distanceM: 1000,
            avgHr: 150,
          ),
        ],
        splits: [
          const Split(km: 1.0, paceSecPerKm: 360),
        ],
      );

      final prompt = GeminiService.buildPrompt(run, []);

      expect(prompt, contains('[워치 랩 기록]'));
      expect(prompt, contains('랩 #1 (1.00km): 6\'00"/km, 소요 6:00 (평균 142bpm)'));
      expect(prompt, contains('랩 #2 (1.00km): 6\'00"/km, 소요 6:00 (평균 150bpm)'));
      expect(prompt, isNot(contains('[구간별 스플릿]')));
    });

    test('buildPrompt categorizes running time slots: night, dawn, and day', () {
      final nightRun = _run(
        km: 5.0,
        durationSec: 1800,
        startTime: DateTime(2026, 8, 1, 22, 30),
      );
      final dawnRun = _run(
        km: 5.0,
        durationSec: 1800,
        startTime: DateTime(2026, 8, 1, 6, 0),
      );
      final dayRun = _run(
        km: 5.0,
        durationSec: 1800,
        startTime: DateTime(2026, 8, 1, 14, 0),
      );

      expect(GeminiService.buildPrompt(nightRun, []), contains('야간 러닝'));
      expect(GeminiService.buildPrompt(dawnRun, []), contains('새벽 러닝'));
      expect(GeminiService.buildPrompt(dayRun, []), contains('주간 러닝'));
    });

    test('buildGoalPrompt includes structured goal coaching sections and stats', () {
      const stats = StatsSummary(
        weekKm: 12.0,
        weekRuns: 2,
        weekSec: 3600,
        totalKm: 50.0,
        totalRuns: 10,
        totalSec: 18000,
        currentStreakWeeks: 3,
        longestRunKm: 8.0,
        best1kPaceSec: 300,
        best5kPaceSec: 1650,
        maxWeekKm: 25.0,
      );

      final monthly = MonthlyStats.fromRuns([
        _run(km: 5.0, durationSec: 1800),
        _run(km: 5.0, durationSec: 1800),
      ]);

      final prompt = GeminiService.buildGoalPrompt(stats, monthly, []);

      expect(prompt, contains('🎯 [다음 1~2주 목표]'));
      expect(prompt, contains('🏃 [추천 세션 구성]'));
      expect(prompt, contains('💡 [코칭 포인트 & 주의사항]'));
      expect(prompt, contains('전체 누적: 10회 / 50.0km'));
      expect(prompt, contains('주 3회 연속 달성(스트릭): 3주'));
      expect(prompt, contains('최장 거리(1회): 8.0km'));
      expect(prompt, contains('개인 최고 페이스: 1km 5\'00"/km / 5km 27\'30"/km'));
    });

    test('buildGoalPrompt handles missing best paces and empty monthly stats cleanly', () {
      const stats = StatsSummary(
        weekKm: 0.0,
        weekRuns: 0,
        weekSec: 0,
        totalKm: 0.0,
        totalRuns: 0,
        totalSec: 0,
        currentStreakWeeks: 0,
        longestRunKm: 0.0,
        best1kPaceSec: null,
        best5kPaceSec: null,
        maxWeekKm: 0.0,
      );

      final monthly = MonthlyStats.fromRuns([]);
      final prompt = GeminiService.buildGoalPrompt(stats, monthly, []);

      expect(prompt, contains('개인 최고 페이스: 1km 기록 없음 / 5km 기록 없음'));
      expect(prompt, contains('평균 페이스 기록 없음'));
      expect(prompt, contains('최근 5회 평균 페이스: 기록 없음'));
    });
  });
}
