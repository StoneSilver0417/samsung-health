import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/services/health/health_data_matcher.dart';
import 'package:runlog/services/health/native_health_channel.dart';

HealthDataPoint _point({
  required String uuid,
  required HealthValue value,
  required HealthDataType type,
  required HealthDataUnit unit,
  required DateTime dateFrom,
  required DateTime dateTo,
  required String sourceId,
  required String sourceName,
}) {
  return HealthDataPoint(
    uuid: uuid,
    value: value,
    type: type,
    unit: unit,
    dateFrom: dateFrom,
    dateTo: dateTo,
    sourcePlatform: HealthPlatformType.values.first,
    sourceDeviceId: 'device-1',
    sourceId: sourceId,
    sourceName: sourceName,
  );
}

void main() {
  group('HealthDataMatcher In-Memory Matching', () {
    final start = DateTime(2026, 8, 1, 21, 0);
    final end = DateTime(2026, 8, 1, 21, 30);
    const sourceId = 'com.sec.android.app.shealth';
    const sourceName = 'Samsung Health';

    test('matchHrSamples extracts only samples within time range and source', () {
      final allHrPoints = [
        _point(
          uuid: 'hr-before',
          value: NumericHealthValue(numericValue: 120),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.subtract(const Duration(minutes: 5)),
          dateTo: start.subtract(const Duration(minutes: 5)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'hr-in-1',
          value: NumericHealthValue(numericValue: 140),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.add(const Duration(minutes: 5)),
          dateTo: start.add(const Duration(minutes: 5)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'hr-in-other-source',
          value: NumericHealthValue(numericValue: 155),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.add(const Duration(minutes: 10)),
          dateTo: start.add(const Duration(minutes: 10)),
          sourceId: 'com.other.app',
          sourceName: 'Other App',
        ),
        _point(
          uuid: 'hr-in-2',
          value: NumericHealthValue(numericValue: 150),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.add(const Duration(minutes: 20)),
          dateTo: start.add(const Duration(minutes: 20)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'hr-after',
          value: NumericHealthValue(numericValue: 100),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: end.add(const Duration(minutes: 5)),
          dateTo: end.add(const Duration(minutes: 5)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      final matched = HealthDataMatcher.matchHrSamples(
        allHrPoints: allHrPoints,
        sessionStart: start,
        sessionEnd: end,
        workoutSourceId: sourceId,
        workoutSourceName: sourceName,
      );

      expect(matched, hasLength(2));
      expect(matched[0].bpm, 140);
      expect(matched[1].bpm, 150);
    });

    test('matchDistanceDeltas filters and sorts deltas within session interval', () {
      final allDistPoints = [
        _point(
          uuid: 'dist-in-2',
          value: NumericHealthValue(numericValue: 500),
          type: HealthDataType.DISTANCE_DELTA,
          unit: HealthDataUnit.METER,
          dateFrom: start.add(const Duration(minutes: 10)),
          dateTo: start.add(const Duration(minutes: 15)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'dist-in-1',
          value: NumericHealthValue(numericValue: 500),
          type: HealthDataType.DISTANCE_DELTA,
          unit: HealthDataUnit.METER,
          dateFrom: start,
          dateTo: start.add(const Duration(minutes: 5)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      final matched = HealthDataMatcher.matchDistanceDeltas(
        allDistPoints: allDistPoints,
        sessionStart: start,
        sessionEnd: end,
        workoutSourceId: sourceId,
        workoutSourceName: sourceName,
      );

      expect(matched, hasLength(2));
      expect(matched[0].from, start);
      expect(matched[1].from, start.add(const Duration(minutes: 10)));
      expect(matched[0].meters, 500);
      expect(matched[1].meters, 500);
    });

    test('matchCalories favors workoutTotalCalories then falls back to summing records', () {
      final allCalPoints = [
        _point(
          uuid: 'cal-1',
          value: NumericHealthValue(numericValue: 150),
          type: HealthDataType.TOTAL_CALORIES_BURNED,
          unit: HealthDataUnit.KILOCALORIE,
          dateFrom: start,
          dateTo: start.add(const Duration(minutes: 15)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'cal-2',
          value: NumericHealthValue(numericValue: 150),
          type: HealthDataType.TOTAL_CALORIES_BURNED,
          unit: HealthDataUnit.KILOCALORIE,
          dateFrom: start.add(const Duration(minutes: 15)),
          dateTo: end,
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      // Case 1: Workout already has summary calories
      final calFromSummary = HealthDataMatcher.matchCalories(
        allCalPoints: allCalPoints,
        sessionStart: start,
        sessionEnd: end,
        workoutSourceId: sourceId,
        workoutSourceName: sourceName,
        workoutTotalCalories: 350.0,
      );
      expect(calFromSummary, 350.0);

      // Case 2: Workout has null calories -> sums from individual points
      final calFromRecords = HealthDataMatcher.matchCalories(
        allCalPoints: allCalPoints,
        sessionStart: start,
        sessionEnd: end,
        workoutSourceId: sourceId,
        workoutSourceName: sourceName,
        workoutTotalCalories: null,
      );
      expect(calFromRecords, 300.0);
    });

    test('matchSteps follows priority: workout totalSteps > nativeSteps > health STEPS', () {
      final allStepsPoints = [
        _point(
          uuid: 'step-1',
          value: NumericHealthValue(numericValue: 2000),
          type: HealthDataType.STEPS,
          unit: HealthDataUnit.COUNT,
          dateFrom: start,
          dateTo: end,
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      // Priority 1: Workout totalSteps
      expect(
        HealthDataMatcher.matchSteps(
          allStepsPoints: allStepsPoints,
          sessionStart: start,
          sessionEnd: end,
          workoutSourceId: sourceId,
          workoutSourceName: sourceName,
          workoutTotalSteps: 5000,
          nativeSteps: 4800,
        ),
        5000,
      );

      // Priority 2: Native steps
      expect(
        HealthDataMatcher.matchSteps(
          allStepsPoints: allStepsPoints,
          sessionStart: start,
          sessionEnd: end,
          workoutSourceId: sourceId,
          workoutSourceName: sourceName,
          workoutTotalSteps: null,
          nativeSteps: 4800,
        ),
        4800,
      );

      // Priority 3: STEPS health data points sum
      expect(
        HealthDataMatcher.matchSteps(
          allStepsPoints: allStepsPoints,
          sessionStart: start,
          sessionEnd: end,
          workoutSourceId: sourceId,
          workoutSourceName: sourceName,
          workoutTotalSteps: null,
          nativeSteps: null,
        ),
        2000,
      );
    });

    test('buildSegmentsAndLaps builds intervals and watch laps with distance and avgHr', () {
      final deltas = [
        DistDelta(
          from: start,
          to: start.add(const Duration(minutes: 10)),
          meters: 1500,
        ),
        DistDelta(
          from: start.add(const Duration(minutes: 10)),
          to: end,
          meters: 3000,
        ),
      ];
      final hrSamples = [
        HrSample(time: start.add(const Duration(minutes: 5)), bpm: 140),
        HrSample(time: start.add(const Duration(minutes: 15)), bpm: 160),
      ];

      final nativeDetail = NativeSessionDetail(
        uuid: 'test-uuid',
        totalSteps: 4500,
        segments: [
          NativeRawSegment(
            start: start,
            end: start.add(const Duration(minutes: 10)),
            type: 'running',
          ),
          NativeRawSegment(
            start: start.add(const Duration(minutes: 10)),
            end: end,
            type: 'walking',
          ),
        ],
        laps: [
          NativeRawLap(
            start: start,
            end: start.add(const Duration(minutes: 10)),
            lengthM: 1500,
          ),
          NativeRawLap(
            start: start.add(const Duration(minutes: 10)),
            end: end,
            lengthM: 3000,
          ),
        ],
      );

      final (segments, laps) = HealthDataMatcher.buildSegmentsAndLaps(
        nativeDetail: nativeDetail,
        deltas: deltas,
        hrSamples: hrSamples,
      );

      expect(segments, hasLength(2));
      expect(segments[0].type, 'running');
      expect(segments[0].distanceM, 1500);
      expect(segments[0].avgHr, 140);
      expect(segments[1].type, 'walking');
      expect(segments[1].distanceM, 3000);
      expect(segments[1].avgHr, 160);

      expect(laps, hasLength(2));
      expect(laps[0].lapNumber, 1);
      expect(laps[0].distanceM, 1500);
      expect(laps[1].lapNumber, 2);
      expect(laps[1].distanceM, 3000);
    });

    test('buildRunSession constructs complete RunSession in memory', () {
      final workoutPoint = _point(
        uuid: 'session-uuid-1',
        value: WorkoutHealthValue(
          workoutActivityType: HealthWorkoutActivityType.RUNNING,
          totalDistance: 4500,
          totalEnergyBurned: 320,
          totalSteps: 4200,
        ),
        type: HealthDataType.WORKOUT,
        unit: HealthDataUnit.NO_UNIT,
        dateFrom: start,
        dateTo: end,
        sourceId: sourceId,
        sourceName: sourceName,
      );

      final workoutValue = workoutPoint.value as WorkoutHealthValue;

      final allHrPoints = [
        _point(
          uuid: 'hr-1',
          value: NumericHealthValue(numericValue: 140),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.add(const Duration(minutes: 5)),
          dateTo: start.add(const Duration(minutes: 5)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
        _point(
          uuid: 'hr-2',
          value: NumericHealthValue(numericValue: 160),
          type: HealthDataType.HEART_RATE,
          unit: HealthDataUnit.BEATS_PER_MINUTE,
          dateFrom: start.add(const Duration(minutes: 25)),
          dateTo: start.add(const Duration(minutes: 25)),
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      final allDistPoints = [
        _point(
          uuid: 'd-1',
          value: NumericHealthValue(numericValue: 4500),
          type: HealthDataType.DISTANCE_DELTA,
          unit: HealthDataUnit.METER,
          dateFrom: start,
          dateTo: end,
          sourceId: sourceId,
          sourceName: sourceName,
        ),
      ];

      final session = HealthDataMatcher.buildRunSession(
        workoutPoint: workoutPoint,
        workoutValue: workoutValue,
        allHrPoints: allHrPoints,
        allDistPoints: allDistPoints,
        allCalPoints: [],
        allStepsPoints: [],
        nativeDetail: null,
        elevation: 15.0,
      );

      expect(session.id, 'session-uuid-1');
      expect(session.distanceM, 4500);
      expect(session.durationSec, 1800);
      expect(session.avgHr, 150);
      expect(session.maxHr, 160);
      expect(session.calories, 320);
      expect(session.steps, 4200);
      expect(session.elevationM, 15.0);
      expect(session.splits, isNotEmpty);
      expect(session.hrSeries, isNotEmpty);
      expect(session.sourceName, sourceName);
    });
  });
}
