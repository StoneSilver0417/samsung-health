import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/gemini/gemini_dto.dart';
import 'package:runlog/services/gemini/gemini_http_client.dart';
import 'package:runlog/services/gemini/gemini_prompt_builder.dart';

void main() {
  group('Gemini Typed DTOs', () {
    test('GeminiPartDto serializes and deserializes correctly', () {
      final partWithThought = const GeminiPartDto(
        text: 'Thinking...',
        thought: true,
      );
      final jsonWithThought = partWithThought.toJson();
      expect(jsonWithThought['text'], 'Thinking...');
      expect(jsonWithThought['thought'], isTrue);

      final fromJson = GeminiPartDto.fromJson(jsonWithThought);
      expect(fromJson.text, 'Thinking...');
      expect(fromJson.thought, isTrue);

      final normalPart = const GeminiPartDto(text: 'Hello, coach!');
      final normalJson = normalPart.toJson();
      expect(normalJson['text'], 'Hello, coach!');
      expect(normalJson.containsKey('thought'), isFalse);

      final fromNormalJson = GeminiPartDto.fromJson(normalJson);
      expect(fromNormalJson.text, 'Hello, coach!');
      expect(fromNormalJson.thought, isFalse);
    });

    test('GeminiContentDto and GeminiGenerationConfigDto conversions', () {
      final content = GeminiContentDto.text('Explain 5K plan');
      final json = content.toJson();
      expect(json['parts'], hasLength(1));
      expect(json['parts'][0]['text'], 'Explain 5K plan');

      final fromJson = GeminiContentDto.fromJson(json);
      expect(fromJson.parts, hasLength(1));
      expect(fromJson.parts.first.text, 'Explain 5K plan');

      const config = GeminiGenerationConfigDto(maxOutputTokens: 1024);
      expect(config.toJson()['maxOutputTokens'], 1024);
      expect(
        GeminiGenerationConfigDto.fromJson({
          'maxOutputTokens': 512,
        }).maxOutputTokens,
        512,
      );
    });

    test(
      'GeminiGenerateRequestDto builds text prompt and serializes to JSON',
      () {
        final req = GeminiGenerateRequestDto.textPrompt(
          'Generate workout advice',
          maxOutputTokens: 2048,
        );
        final rawJson = req.toRawJson();
        final map = jsonDecode(rawJson) as Map<String, dynamic>;

        expect(
          map['contents'][0]['parts'][0]['text'],
          'Generate workout advice',
        );
        expect(map['generationConfig']['maxOutputTokens'], 2048);

        final fromJson = GeminiGenerateRequestDto.fromJson(map);
        expect(
          fromJson.contents.first.parts.first.text,
          'Generate workout advice',
        );
        expect(fromJson.generationConfig.maxOutputTokens, 2048);
      },
    );

    test(
      'GeminiGenerateResponseDto extracts clean text and ignores thought: true',
      () {
        final raw = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'Drafting internally...', 'thought': true},
                  {'text': '🎯 목표: 이번 주 15km 완주'},
                ],
              },
            },
          ],
        });

        final res = GeminiGenerateResponseDto.fromRawJson(raw);
        expect(res.candidates, hasLength(1));
        expect(res.extractCleanText(), '🎯 목표: 이번 주 15km 완주');
      },
    );

    test(
      'GeminiGenerateResponseDto throws when candidates list is empty or text is blank',
      () {
        final emptyRes = const GeminiGenerateResponseDto(candidates: []);
        expect(
          () => emptyRes.extractCleanText(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Gemini 응답에 결과가 없습니다'),
            ),
          ),
        );

        final blankRes = GeminiGenerateResponseDto(
          candidates: [
            GeminiCandidateDto(
              content: GeminiContentDto(
                parts: [
                  const GeminiPartDto(text: '   '),
                  const GeminiPartDto(text: 'Hidden thought', thought: true),
                ],
              ),
            ),
          ],
        );
        expect(
          () => blankRes.extractCleanText(),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Gemini 응답이 비어있습니다'),
            ),
          ),
        );
      },
    );
  });

  group('GeminiPromptBuilder', () {
    test('calculates average pace filtering zero and negative values', () {
      final runs = [
        RunSession(
          id: '1',
          startTime: DateTime(2026, 8, 1),
          endTime: DateTime(2026, 8, 1, 0, 30),
          distanceM: 5000,
          durationSec: 1800, // 360s/km (6:00)
        ),
        RunSession(
          id: '2',
          startTime: DateTime(2026, 8, 2),
          endTime: DateTime(2026, 8, 2, 0, 10),
          distanceM: 0,
          durationSec: 600, // 0 pace
        ),
        RunSession(
          id: '3',
          startTime: DateTime(2026, 8, 3),
          endTime: DateTime(2026, 8, 3, 0, 25),
          distanceM: 5000,
          durationSec: 1500, // 300s/km (5:00)
        ),
      ];

      expect(GeminiPromptBuilder.averagePaceSecPerKm(runs), 330);
      expect(GeminiPromptBuilder.averagePaceSecPerKm([]), isNull);
    });

    test(
      'buildRunSummaryPrompt and buildGoalRecommendationPrompt structure',
      () {
        final run = RunSession(
          id: 'r1',
          startTime: DateTime(2026, 8, 1, 22), // 야간
          endTime: DateTime(2026, 8, 1, 22, 30),
          distanceM: 5000,
          durationSec: 1800,
          avgHr: 145,
          maxHr: 165,
          calories: 320,
          steps: 4500,
          elevationM: 20.0,
        );

        final prompt = GeminiPromptBuilder.buildRunSummaryPrompt(run, []);
        expect(prompt, contains('[핵심 요약]'));
        expect(prompt, contains('[페이스 & 심박 분석]'));
        expect(prompt, contains('[맞춤 코칭 팁]'));
        expect(prompt, contains('야간 러닝'));
        expect(prompt, contains('5.00km'));

        const stats = StatsSummary(
          weekKm: 15.0,
          weekRuns: 3,
          weekSec: 5400,
          totalKm: 100.0,
          totalRuns: 20,
          totalSec: 36000,
          currentStreakWeeks: 4,
          longestRunKm: 10.0,
          best1kPaceSec: 300,
          best5kPaceSec: 1600,
          maxWeekKm: 30.0,
        );
        final goalPrompt = GeminiPromptBuilder.buildGoalRecommendationPrompt(
          stats,
          MonthlyStats.fromRuns([run]),
          [run],
        );
        expect(goalPrompt, contains('🎯 [다음 1~2주 목표]'));
        expect(goalPrompt, contains('🏃 [추천 세션 구성]'));
        expect(goalPrompt, contains('💡 [코칭 포인트 & 주의사항]'));
      },
    );

    test('marks supplied splits as available authoritative interval data', () {
      final run = RunSession(
        id: 'split-run',
        startTime: DateTime(2026, 8, 1, 21),
        endTime: DateTime(2026, 8, 1, 21, 20),
        distanceM: 3000,
        durationSec: 1200,
        splits: const [
          Split(km: 1, paceSecPerKm: 420),
          Split(km: 2, paceSecPerKm: 400),
          Split(km: 3, paceSecPerKm: 380),
        ],
      );

      final prompt = GeminiPromptBuilder.buildRunSummaryPrompt(run, const []);

      expect(prompt, contains('실제 측정된 구간 데이터가 있다'));
      expect(prompt, contains('구간별 페이스를 알 수 없다'));
      expect(prompt, contains('[구간별 스플릿]'));
      expect(prompt, contains('1km: 7\'00"/km'));
      expect(prompt, contains('3km: 6\'20"/km'));
      expect(prompt, isNot(contains('구간별 변화를 추측하거나 만들어내지 말고')));
    });

    test('forbids invented interval claims when no laps or splits exist', () {
      final run = RunSession(
        id: 'no-splits',
        startTime: DateTime(2026, 8, 1, 21),
        endTime: DateTime(2026, 8, 1, 21, 30),
        distanceM: 5000,
        durationSec: 1800,
      );

      final prompt = GeminiPromptBuilder.buildRunSummaryPrompt(run, const []);

      expect(prompt, contains('실제 측정된 구간 데이터가 없다'));
      expect(prompt, contains('구간별 변화를 추측하거나 만들어내지 말고'));
      expect(prompt, contains('전체 평균 페이스를 분석하되'));
      expect(prompt, isNot(contains('[구간별 스플릿]')));
    });
  });

  group('GeminiHttpEngine direct tests', () {
    test('executes generate and returns typed response DTO', () async {
      final mockClient = MockClient((request) async {
        expect(request.headers['x-goog-api-key'], 'test-key');
        expect(request.headers['Content-Type'], 'application/json');
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '멋진 러닝이었습니다.'},
                  ],
                },
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final engine = GeminiHttpEngine(client: mockClient);
      final response = await engine.generate(
        apiKey: 'test-key',
        request: GeminiGenerateRequestDto.textPrompt('Analyze run'),
      );

      expect(response.extractCleanText(), '멋진 러닝이었습니다.');
    });

    test('throws GeminiNotConfiguredException when apiKey is empty', () async {
      final engine = GeminiHttpEngine();
      expect(
        () => engine.generate(
          apiKey: '',
          request: GeminiGenerateRequestDto.textPrompt('Test'),
        ),
        throwsA(isA<GeminiNotConfiguredException>()),
      );
    });
  });
}
