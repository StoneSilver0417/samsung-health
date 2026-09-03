import 'package:flutter_test/flutter_test.dart';
import 'package:runlog/models/run_session.dart';

void main() {
  group('Running Dynamics & Cardio Efficiency metrics', () {
    test('strideCm calculates stride length in cm correctly', () {
      final session = RunSession(
        id: 'stride-test',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 30),
        distanceM: 5000,
        durationSec: 1800,
        steps: 5000,
      );

      // 5000m / 5000 steps = 1.0m = 100cm
      expect(session.strideCm, 100.0);

      final sessionNoSteps = RunSession(
        id: 'no-steps',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 30),
        distanceM: 5000,
        durationSec: 1800,
        steps: null,
      );
      expect(sessionNoSteps.strideCm, isNull);
    });

    test('cardiacDriftPct compares first half vs second half average HR', () {
      final samples = [
        HrSample(time: DateTime(2026, 9, 3, 21, 0), bpm: 130),
        HrSample(time: DateTime(2026, 9, 3, 21, 5), bpm: 130),
        HrSample(time: DateTime(2026, 9, 3, 21, 10), bpm: 143),
        HrSample(time: DateTime(2026, 9, 3, 21, 15), bpm: 143),
      ];

      final session = RunSession(
        id: 'drift-test',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 20),
        distanceM: 3000,
        durationSec: 1200,
        hrSeries: samples,
      );

      // 1st half avg: 130, 2nd half avg: 143
      // Drift: (143 - 130) / 130 * 100 = 10.0%
      expect(session.cardiacDriftPct, closeTo(10.0, 0.01));
    });

    test('cardiacDriftPct returns null when hr samples are fewer than 4', () {
      final samples = [
        HrSample(time: DateTime(2026, 9, 3, 21, 0), bpm: 130),
        HrSample(time: DateTime(2026, 9, 3, 21, 5), bpm: 135),
      ];

      final session = RunSession(
        id: 'drift-short',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 10),
        distanceM: 1000,
        durationSec: 600,
        hrSeries: samples,
      );

      expect(session.cardiacDriftPct, isNull);
    });

    test('aerobicAnaerobicRatio divides Z1~Z3 (<80% maxHr) vs Z4~Z5 (>=80% maxHr)', () {
      // Max HR = 200 bpm
      // 80% of 200 = 160 bpm
      final samples = [
        HrSample(time: DateTime(2026, 9, 3, 21, 0), bpm: 140), // <160 (aerobic)
        HrSample(time: DateTime(2026, 9, 3, 21, 5), bpm: 150), // <160 (aerobic)
        HrSample(time: DateTime(2026, 9, 3, 21, 10), bpm: 155), // <160 (aerobic)
        HrSample(time: DateTime(2026, 9, 3, 21, 15), bpm: 170), // >=160 (anaerobic)
      ];

      final session = RunSession(
        id: 'ratio-test',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 20),
        distanceM: 3000,
        durationSec: 1200,
        maxHr: 200,
        hrSeries: samples,
      );

      final ratio = session.aerobicAnaerobicRatio;
      expect(ratio, isNotNull);
      expect(ratio!.aerobicPct, 75.0);
      expect(ratio.anaerobicPct, 25.0);
    });

    test('trainingLoadScore and recommendedRecoveryHours', () {
      final session = RunSession(
        id: 'load-test',
        startTime: DateTime(2026, 9, 3, 21),
        endTime: DateTime(2026, 9, 3, 21, 30),
        distanceM: 5000,
        durationSec: 1800, // 30 minutes
        maxHr: 200,
        hrSeries: [
          HrSample(time: DateTime(2026, 9, 3, 21, 0), bpm: 130), // 65% -> Zone 2 (1.5)
          HrSample(time: DateTime(2026, 9, 3, 21, 15), bpm: 150), // 75% -> Zone 3 (2.2)
        ],
      );

      // 30 min * ((1.5 + 2.2)/2 = 1.85) = 55.5 -> 56 pt
      expect(session.trainingLoadScore, 56);
      expect(session.recommendedRecoveryHours, 18); // 30 <= load < 60 -> 18h
    });

    test('RunLap model JSON serialization and methods', () {
      final lap = RunLap(
        lapNumber: 1,
        startTime: DateTime(2026, 9, 3, 21, 0),
        endTime: DateTime(2026, 9, 3, 21, 6),
        distanceM: 1000,
        avgHr: 148,
      );

      expect(lap.durationSec, 360);
      expect(lap.distanceKm, 1.0);
      expect(lap.paceSecPerKm, 360);

      final json = lap.toJson();
      final restored = RunLap.fromJson(json);

      expect(restored.lapNumber, 1);
      expect(restored.distanceM, 1000);
      expect(restored.avgHr, 148);
      expect(restored.durationSec, 360);
    });
  });
}
