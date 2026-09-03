import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/gemini_service.dart';

RunSession _run({
  required double km,
  required int durationSec,
  double? avgHr,
  double? maxHr,
  int? steps,
  double? elevationM,
  List<Split> splits = const [],
  List<HrSample> hrSeries = const [],
}) =>
    RunSession(
      id: '$km-$durationSec',
      startTime: DateTime(2026, 8, 1, 21),
      endTime: DateTime(2026, 8, 1, 21).add(Duration(seconds: durationSec)),
      distanceM: km * 1000,
      durationSec: durationSec,
      avgHr: avgHr,
      maxHr: maxHr,
      steps: steps,
      elevationM: elevationM,
      splits: splits,
      hrSeries: hrSeries,
    );

void main() {
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

    expect(prompt, contains('📌 [핵심 요약]'));
    expect(prompt, contains('📊 [페이스 & 심박 분석]'));
    expect(prompt, contains('💡 [맞춤 코칭 팁]'));
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
}
