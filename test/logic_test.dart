import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/health_service.dart';

void main() {
  group('computeSplits', () {
    test('일정 페이스 6분/km, 2.5km → 1km 2개 + 부분 스플릿', () {
      final start = DateTime(2026, 6, 1, 21, 0);
      // 100m를 36초마다 (= 6'00"/km), 총 2500m
      final deltas = List.generate(25, (i) {
        return DistDelta(
          from: start.add(Duration(seconds: 36 * i)),
          to: start.add(Duration(seconds: 36 * (i + 1))),
          meters: 100,
        );
      });

      final splits = HealthService.computeSplits(start, deltas, const []);

      expect(splits.length, 3);
      expect(splits[0].km, 1.0);
      expect(splits[0].paceSecPerKm, 360);
      expect(splits[1].paceSecPerKm, 360);
      // 마지막 0.5km 부분 스플릿: 환산 페이스도 6분
      expect(splits[2].km, 2.5);
      expect(splits[2].paceSecPerKm, 360);
    });

    test('300m 미만 잔여 거리는 부분 스플릿 미생성', () {
      final start = DateTime(2026, 6, 1);
      final deltas = [
        DistDelta(
            from: start,
            to: start.add(const Duration(minutes: 7)),
            meters: 1200),
      ];
      final splits = HealthService.computeSplits(start, deltas, const []);
      expect(splits.length, 1);
      expect(splits[0].km, 1.0);
    });

    test('델타 없으면 빈 스플릿 (삼성헬스 미제공 케이스)', () {
      expect(HealthService.computeSplits(DateTime.now(), [], const []), isEmpty);
    });
  });

  group('downsampleHr', () {
    test('1분 버킷 평균', () {
      final start = DateTime(2026, 6, 1);
      final samples = List.generate(
        120,
        (i) => HrSample(
            time: start.add(Duration(seconds: i)), bpm: 100 + (i % 2)),
      );
      final out =
          HealthService.downsampleHr(samples, const Duration(minutes: 1));
      expect(out.length, 2);
      expect(out[0].bpm, closeTo(100.5, 0.01));
    });
  });

  group('StatsSummary', () {
    RunSession run(DateTime start, double km, int sec) => RunSession(
          id: '$start',
          startTime: start,
          endTime: start.add(Duration(seconds: sec)),
          distanceM: km * 1000,
          durationSec: sec,
        );

    test('이번 주 합계와 누적', () {
      final now = DateTime(2026, 6, 11); // 목요일
      final runs = [
        run(DateTime(2026, 6, 9, 21), 5, 1800), // 이번 주 (화)
        run(DateTime(2026, 6, 10, 21), 3, 1200), // 이번 주 (수)
        run(DateTime(2026, 6, 2, 21), 4, 1500), // 지난 주
      ];
      final s = StatsSummary.fromRuns(runs, now: now);
      expect(s.weekKm, closeTo(8, 0.001));
      expect(s.weekRuns, 2);
      expect(s.totalKm, closeTo(12, 0.001));
      expect(s.totalRuns, 3);
    });

    test('주 3회 스트릭: 지난 2주 연속 3회 + 이번 주 진행 중', () {
      final now = DateTime(2026, 6, 11);
      final runs = <RunSession>[];
      // 지난 주(6/1 시작), 지지난 주(5/25 시작) 각 3회
      for (final weekStart in [DateTime(2026, 6, 1), DateTime(2026, 5, 25)]) {
        for (int d = 0; d < 3; d++) {
          runs.add(run(weekStart.add(Duration(days: d, hours: 21)), 3, 1200));
        }
      }
      // 이번 주는 1회뿐 — 진행 중이므로 스트릭 유지
      runs.add(run(DateTime(2026, 6, 9, 21), 3, 1200));
      final s = StatsSummary.fromRuns(runs, now: now);
      expect(s.currentStreakWeeks, 2);
    });

    test('페이스 포맷', () {
      expect(fmtPace(360), "6'00\"");
      expect(fmtPace(412), "6'52\"");
      expect(fmtDuration(3725), '1:02:05');
      expect(fmtDuration(1800), '30:00');
    });
  });
}
