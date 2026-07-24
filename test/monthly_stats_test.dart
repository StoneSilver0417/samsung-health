import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/logic/stats.dart';
import 'package:runlog/models/run_session.dart';

RunSession _run(DateTime start, double km, int sec) => RunSession(
  id: '${start.toIso8601String()}-$km-$sec',
  startTime: start,
  endTime: start.add(Duration(seconds: sec)),
  distanceM: km * 1000,
  durationSec: sec,
);

void main() {
  group('MonthlyStats', () {
    test('이번 달과 지난달 경계를 분리해 집계한다', () {
      final stats = MonthlyStats.fromRuns(
        [
          _run(DateTime(2026, 6, 30, 23, 59), 2, 720),
          _run(DateTime(2026, 7, 1), 5, 1800),
          _run(DateTime(2026, 7, 31, 23, 59), 3, 1200),
          _run(DateTime(2026, 8, 1), 10, 3600),
        ],
        now: DateTime(2026, 7, 15),
      );

      expect(stats.thisMonthKm, closeTo(8, 0.001));
      expect(stats.thisMonthRuns, 2);
      expect(stats.thisMonthSec, 3000);
      expect(stats.thisMonthLongestKm, closeTo(5, 0.001));
      expect(stats.lastMonthKm, closeTo(2, 0.001));
      expect(stats.lastMonthRuns, 1);
      expect(stats.lastMonthSec, 720);
    });

    test('최근 6개월을 오래된 순서로 만들고 기록 없는 달을 0으로 채운다', () {
      final stats = MonthlyStats.fromRuns(
        [
          _run(DateTime(2026, 3, 10), 4, 1440),
          _run(DateTime(2026, 7, 10), 5, 1800),
        ],
        now: DateTime(2026, 7, 24),
      );

      expect(stats.monthlyKm, hasLength(6));
      expect(
        stats.monthlyKm.map((entry) => entry.$1).toList(),
        [
          DateTime(2026, 2),
          DateTime(2026, 3),
          DateTime(2026, 4),
          DateTime(2026, 5),
          DateTime(2026, 6),
          DateTime(2026, 7),
        ],
      );
      expect(
        stats.monthlyKm.map((entry) => entry.$2).toList(),
        [0, 4, 0, 0, 0, 5],
      );
    });

    test('월 평균 페이스는 총시간을 총거리로 나눈 거리 가중 평균이다', () {
      final stats = MonthlyStats.fromRuns(
        [
          _run(DateTime(2026, 7, 3), 2, 600),
          _run(DateTime(2026, 7, 10), 8, 3200),
          _run(DateTime(2026, 6, 10), 3, 1081),
        ],
        now: DateTime(2026, 7, 24),
      );

      expect(stats.thisMonthAvgPaceSec, 380);
      expect(stats.lastMonthAvgPaceSec, 360);

      final empty = MonthlyStats.fromRuns([], now: DateTime(2026, 7, 24));
      expect(empty.thisMonthAvgPaceSec, isNull);
      expect(empty.lastMonthAvgPaceSec, isNull);

      final zeroDistance = MonthlyStats.fromRuns(
        [_run(DateTime(2026, 7, 12), 0, 600)],
        now: DateTime(2026, 7, 24),
      );
      expect(zeroDistance.thisMonthAvgPaceSec, isNull);
    });

    test('1월 기준으로 지난 12월과 최근 6개월의 연도를 정확히 처리한다', () {
      final stats = MonthlyStats.fromRuns(
        [
          _run(DateTime(2026, 12, 31, 23, 59), 4, 1440),
          _run(DateTime(2027, 1, 1), 5, 1800),
        ],
        now: DateTime(2027, 1, 20),
      );

      expect(
        MonthlyStats.monthStart(DateTime(2026, 12, 31)),
        DateTime(2026, 12),
      );
      expect(MonthlyStats.monthStart(DateTime(2027, 1, 31)), DateTime(2027, 1));
      expect(stats.thisMonthKm, closeTo(5, 0.001));
      expect(stats.lastMonthKm, closeTo(4, 0.001));
      expect(
        stats.monthlyKm.map((entry) => entry.$1).toList(),
        [
          DateTime(2026, 8),
          DateTime(2026, 9),
          DateTime(2026, 10),
          DateTime(2026, 11),
          DateTime(2026, 12),
          DateTime(2027, 1),
        ],
      );
      expect(
        stats.monthlyKm.map((entry) => entry.$2).toList(),
        [0, 0, 0, 0, 4, 5],
      );
    });
  });
}
