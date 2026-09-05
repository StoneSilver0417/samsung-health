import 'package:health/health.dart';

import '../../models/run_session.dart';
import 'native_health_channel.dart';

/// Health Connect DISTANCE_DELTA 1건 (테스트에서 직접 생성 가능하도록 공개)
class DistDelta {
  final DateTime from;
  final DateTime to;
  final double meters;

  const DistDelta({
    required this.from,
    required this.to,
    required this.meters,
  });
}

/// 기간 단위 Bulk 조회된 Health Connect 데이터들을 개별 러닝 세션으로
/// 메모리 상에서 고속 매칭·변환하는 헬퍼 클래스.
class HealthDataMatcher {
  const HealthDataMatcher._();

  /// 데이터 포인트의 출처(패키지명/sourceId/sourceName)가 워크아웃 출처와 일치하는지 판별
  static bool sameSource(
    String dataSourceId,
    String workoutSourceId, {
    String dataSourceName = '',
    String workoutSourceName = '',
  }) {
    if (dataSourceId.isNotEmpty && workoutSourceId.isNotEmpty) {
      if (dataSourceId == workoutSourceId) return true;
    }
    if (dataSourceName.isNotEmpty && workoutSourceName.isNotEmpty) {
      if (dataSourceName == workoutSourceName) return true;
    }
    // Cross-match: e.g. Health Connect interval records where source_name contains package name and source_id is empty
    if (dataSourceName.isNotEmpty && workoutSourceId.isNotEmpty) {
      if (dataSourceName == workoutSourceId) return true;
    }
    if (dataSourceId.isNotEmpty && workoutSourceName.isNotEmpty) {
      if (dataSourceId == workoutSourceName) return true;
    }

    final isTargetSamsung = workoutSourceId.contains('shealth') ||
        workoutSourceId.contains('samsung') ||
        workoutSourceName.contains('shealth') ||
        workoutSourceName.toLowerCase().contains('samsung');
    if (isTargetSamsung) {
      final isPointSamsung = dataSourceId.contains('shealth') ||
          dataSourceId.contains('samsung') ||
          dataSourceName.contains('shealth') ||
          dataSourceName.toLowerCase().contains('samsung');
      if (isPointSamsung) return true;
    }

    if (dataSourceId.isEmpty && dataSourceName.isEmpty) {
      return true;
    }

    return dataSourceId == workoutSourceId;
  }

  /// [from]~[to] 구간의 거리(미터) — 델타가 경계에 걸치면 시간 비례 배분
  static double distanceBetween(
    List<DistDelta> deltas,
    DateTime from,
    DateTime to,
  ) {
    double sum = 0;
    for (final d in deltas) {
      final overlapStart = d.from.isAfter(from) ? d.from : from;
      final overlapEnd = d.to.isBefore(to) ? d.to : to;
      final overlapMs =
          overlapEnd.difference(overlapStart).inMilliseconds;
      if (overlapMs <= 0) continue;
      final spanMs = d.to.difference(d.from).inMilliseconds;
      sum += spanMs > 0 ? d.meters * overlapMs / spanMs : d.meters;
    }
    return sum;
  }

  /// [from]~[to] 구간의 평균 심박수 산출
  static double? avgHrBetween(
    List<HrSample> samples,
    DateTime from,
    DateTime to,
  ) {
    final inRange = samples
        .where((h) => !h.time.isBefore(from) && !h.time.isAfter(to))
        .toList();
    if (inRange.isEmpty) return null;
    return inRange.fold<double>(0, (s, h) => s + h.bpm) / inRange.length;
  }

  /// 거리 델타 시계열로 km별 스플릿 산출.
  /// 1km 경계를 넘는 델타 구간은 선형 보간으로 통과 시각을 추정한다.
  /// 삼성헬스가 델타를 안 쓰는 경우 빈 리스트가 되어 스플릿 미표시.
  static List<Split> computeSplits(
    DateTime sessionStart,
    List<DistDelta> deltas,
    List<HrSample> hrSamples,
  ) {
    if (deltas.isEmpty) return const [];

    final splits = <Split>[];
    double cumM = 0;
    int nextKm = 1;
    DateTime lastCross = sessionStart;

    for (final d in deltas) {
      final spanSec = d.to.difference(d.from).inMilliseconds / 1000.0;
      double segStartM = cumM;
      cumM += d.meters;

      while (cumM >= nextKm * 1000) {
        final needed = nextKm * 1000 - segStartM;
        final frac = d.meters > 0 ? (needed / d.meters).clamp(0.0, 1.0) : 0.0;
        final crossTime = d.from.add(
          Duration(milliseconds: (spanSec * 1000 * frac).round()),
        );
        final paceSec = crossTime.difference(lastCross).inSeconds;
        splits.add(
          Split(
            km: nextKm.toDouble(),
            paceSecPerKm: paceSec,
            avgHr: avgHrBetween(hrSamples, lastCross, crossTime),
          ),
        );
        lastCross = crossTime;
        nextKm++;
      }
    }

    // 마지막 부분 km (300m 이상일 때만 표시, 환산 페이스)
    final remainM = cumM - (nextKm - 1) * 1000;
    if (remainM >= 300) {
      final remainSec = deltas.last.to.difference(lastCross).inSeconds;
      splits.add(
        Split(
          km: double.parse((cumM / 1000).toStringAsFixed(2)),
          paceSecPerKm: (remainSec / (remainM / 1000)).round(),
          avgHr: avgHrBetween(hrSamples, lastCross, deltas.last.to),
        ),
      );
    }
    return splits;
  }

  /// Firestore 1MB 문서 제한 대비 다운샘플링 (PRD 5). 로컬 저장도 동일 적용.
  static List<HrSample> downsampleHr(
    List<HrSample> samples,
    Duration bucket,
  ) {
    if (samples.isEmpty) return const [];
    final out = <HrSample>[];
    DateTime bucketStart = samples.first.time;
    final acc = <double>[];
    for (final s in samples) {
      if (s.time.difference(bucketStart) >= bucket) {
        out.add(
          HrSample(
            time: bucketStart,
            bpm: acc.reduce((a, b) => a + b) / acc.length,
          ),
        );
        bucketStart = s.time;
        acc.clear();
      }
      acc.add(s.bpm);
    }
    if (acc.isNotEmpty) {
      out.add(
        HrSample(
          time: bucketStart,
          bpm: acc.reduce((a, b) => a + b) / acc.length,
        ),
      );
    }
    return out;
  }

  /// 전체 심박 데이터 포인트 중 특정 세션 구간 및 출처에 해당하는 심박 시계열 필터링
  static List<HrSample> matchHrSamples({
    required List<HealthDataPoint> allHrPoints,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String workoutSourceId,
    required String workoutSourceName,
  }) {
    return allHrPoints
        .where((p) =>
            !p.dateTo.isBefore(sessionStart) &&
            !p.dateFrom.isAfter(sessionEnd) &&
            sameSource(
              p.sourceId,
              workoutSourceId,
              dataSourceName: p.sourceName,
              workoutSourceName: workoutSourceName,
            ) &&
            p.value is NumericHealthValue)
        .map(
          (p) => HrSample(
            time: p.dateFrom,
            bpm: (p.value as NumericHealthValue).numericValue.toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
  }

  /// 전체 거리 델타 포인트 중 특정 세션 구간 및 출처에 해당하는 델타 필터링
  static List<DistDelta> matchDistanceDeltas({
    required List<HealthDataPoint> allDistPoints,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String workoutSourceId,
    required String workoutSourceName,
  }) {
    return allDistPoints
        .where((p) =>
            !p.dateTo.isBefore(sessionStart) &&
            !p.dateFrom.isAfter(sessionEnd) &&
            sameSource(
              p.sourceId,
              workoutSourceId,
              dataSourceName: p.sourceName,
              workoutSourceName: workoutSourceName,
            ) &&
            p.value is NumericHealthValue)
        .map(
          (p) => DistDelta(
            from: p.dateFrom,
            to: p.dateTo,
            meters: (p.value as NumericHealthValue).numericValue.toDouble(),
          ),
        )
        .toList()
      ..sort((a, b) => a.from.compareTo(b.from));
  }

  /// 칼로리 매칭 (Workout 집계값 우선, 없을 시 개별 칼로리 레코드 합산)
  static double? matchCalories({
    required List<HealthDataPoint> allCalPoints,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String workoutSourceId,
    required String workoutSourceName,
    required double? workoutTotalCalories,
  }) {
    if (workoutTotalCalories != null && workoutTotalCalories > 0) {
      return workoutTotalCalories;
    }
    final calSum = allCalPoints
        .where((p) =>
            !p.dateTo.isBefore(sessionStart) &&
            !p.dateFrom.isAfter(sessionEnd) &&
            sameSource(
              p.sourceId,
              workoutSourceId,
              dataSourceName: p.sourceName,
              workoutSourceName: workoutSourceName,
            ) &&
            p.value is NumericHealthValue)
        .fold<double>(
          0,
          (sum, p) => sum + (p.value as NumericHealthValue).numericValue,
        );
    return calSum > 0 ? calSum : null;
  }

  /// 걸음 수 매칭 (Workout 집계값 > 네이티브 직독 > health 패키지 STEPS 합산)
  static int? matchSteps({
    required List<HealthDataPoint> allStepsPoints,
    required DateTime sessionStart,
    required DateTime sessionEnd,
    required String workoutSourceId,
    required String workoutSourceName,
    required int? workoutTotalSteps,
    required int? nativeSteps,
  }) {
    if (workoutTotalSteps != null && workoutTotalSteps > 0) {
      return workoutTotalSteps;
    }
    if (nativeSteps != null && nativeSteps > 0) {
      return nativeSteps;
    }
    final sumSteps = allStepsPoints
        .where((p) =>
            !p.dateTo.isBefore(sessionStart) &&
            !p.dateFrom.isAfter(sessionEnd) &&
            sameSource(
              p.sourceId,
              workoutSourceId,
              dataSourceName: p.sourceName,
              workoutSourceName: workoutSourceName,
            ) &&
            p.value is NumericHealthValue)
        .fold<double>(
          0,
          (sum, p) => sum + (p.value as NumericHealthValue).numericValue,
        )
        .round();
    return sumSteps > 0 ? sumSteps : null;
  }

  /// 네이티브 세션 상세(인터벌 세그먼트, 랩) 매칭 및 거리/심박수 결합
  static (List<RunSegment>, List<RunLap>) buildSegmentsAndLaps({
    required NativeSessionDetail? nativeDetail,
    required List<DistDelta> deltas,
    required List<HrSample> hrSamples,
  }) {
    if (nativeDetail == null) {
      return (const <RunSegment>[], const <RunLap>[]);
    }

    final segments = nativeDetail.segments.map((m) {
      return RunSegment(
        startTime: m.start,
        endTime: m.end,
        type: m.type,
        distanceM: distanceBetween(deltas, m.start, m.end),
        avgHr: avgHrBetween(hrSamples, m.start, m.end),
      );
    }).toList();

    int lapIdx = 1;
    final laps = nativeDetail.laps.map((m) {
      final dist = m.lengthM > 0
          ? m.lengthM
          : distanceBetween(deltas, m.start, m.end);
      return RunLap(
        lapNumber: lapIdx++,
        startTime: m.start,
        endTime: m.end,
        distanceM: dist,
        avgHr: avgHrBetween(hrSamples, m.start, m.end),
      );
    }).toList();

    return (segments, laps);
  }

  /// 개별 워크아웃 포인트와 벌크 데이터들을 조합하여 완결된 RunSession 인스턴스 구성
  static RunSession buildRunSession({
    required HealthDataPoint workoutPoint,
    required WorkoutHealthValue workoutValue,
    required List<HealthDataPoint> allHrPoints,
    required List<HealthDataPoint> allDistPoints,
    required List<HealthDataPoint> allCalPoints,
    required List<HealthDataPoint> allStepsPoints,
    required NativeSessionDetail? nativeDetail,
    required double elevation,
  }) {
    final start = workoutPoint.dateFrom;
    final end = workoutPoint.dateTo;
    final sourceId = workoutPoint.sourceId;
    final sourceName = workoutPoint.sourceName;

    // 세션 구간의 심박 시계열
    final hrSamples = matchHrSamples(
      allHrPoints: allHrPoints,
      sessionStart: start,
      sessionEnd: end,
      workoutSourceId: sourceId,
      workoutSourceName: sourceName,
    );

    // 세션 구간의 거리 델타 (스플릿 산출용)
    final deltas = matchDistanceDeltas(
      allDistPoints: allDistPoints,
      sessionStart: start,
      sessionEnd: end,
      workoutSourceId: sourceId,
      workoutSourceName: sourceName,
    );

    final deltaSum = deltas.fold<double>(0, (sum, d) => sum + d.meters);
    final distanceM = (workoutValue.totalDistance?.toDouble() ?? 0) > 0
        ? workoutValue.totalDistance!.toDouble()
        : deltaSum;

    final calories = matchCalories(
      allCalPoints: allCalPoints,
      sessionStart: start,
      sessionEnd: end,
      workoutSourceId: sourceId,
      workoutSourceName: sourceName,
      workoutTotalCalories: workoutValue.totalEnergyBurned?.toDouble(),
    );

    final steps = matchSteps(
      allStepsPoints: allStepsPoints,
      sessionStart: start,
      sessionEnd: end,
      workoutSourceId: sourceId,
      workoutSourceName: sourceName,
      workoutTotalSteps: workoutValue.totalSteps,
      nativeSteps: nativeDetail?.totalSteps,
    );

    final (segments, laps) = buildSegmentsAndLaps(
      nativeDetail: nativeDetail,
      deltas: deltas,
      hrSamples: hrSamples,
    );

    final avgHr = hrSamples.isEmpty
        ? null
        : hrSamples.fold<double>(0, (s, h) => s + h.bpm) / hrSamples.length;
    final maxHr = hrSamples.isEmpty
        ? null
        : hrSamples.map((h) => h.bpm).reduce((a, b) => a > b ? a : b);

    return RunSession(
      id: workoutPoint.uuid,
      startTime: start,
      endTime: end,
      distanceM: distanceM,
      durationSec: end.difference(start).inSeconds,
      avgHr: avgHr,
      maxHr: maxHr,
      calories: calories,
      steps: steps,
      elevationM: elevation > 0 ? elevation : null,
      segments: segments,
      laps: laps,
      splits: computeSplits(start, deltas, hrSamples),
      hrSeries: downsampleHr(hrSamples, const Duration(minutes: 1)),
      sourceName: sourceName,
    );
  }
}
