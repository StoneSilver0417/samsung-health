import 'package:health/health.dart';

import '../../models/run_session.dart';
import 'native_health_channel.dart';

/// Health Connect DISTANCE_DELTA 1건 (테스트에서 직접 생성 가능하도록 공개)
class DistDelta {
  final DateTime from;
  final DateTime to;
  final double meters;

  const DistDelta({required this.from, required this.to, required this.meters});
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

    final isTargetSamsung =
        workoutSourceId.contains('shealth') ||
        workoutSourceId.contains('samsung') ||
        workoutSourceName.contains('shealth') ||
        workoutSourceName.toLowerCase().contains('samsung');
    if (isTargetSamsung) {
      final isPointSamsung =
          dataSourceId.contains('shealth') ||
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

  /// 거리 델타 시계열에서 중복/포괄하는 매크로 집계/중복 시간 구간 델타를 제거하여
  /// 거리 2배 중복 합산(distance doubling)을 방지한다.
  static List<DistDelta> deduplicateDistanceDeltas(List<DistDelta> rawDeltas) {
    if (rawDeltas.length <= 1) return rawDeltas;

    final valid = rawDeltas
        .where((d) => d.meters >= 0 && d.to.isAfter(d.from))
        .toList();
    if (valid.length <= 1) return valid;

    // 1. 동일 시간 구간의 중복 델타 통합 (더 큰 거리 유지)
    final uniqueSpanMap = <String, DistDelta>{};
    for (final d in valid) {
      final key =
          '${d.from.millisecondsSinceEpoch}-${d.to.millisecondsSinceEpoch}';
      if (!uniqueSpanMap.containsKey(key) ||
          d.meters > uniqueSpanMap[key]!.meters) {
        uniqueSpanMap[key] = d;
      }
    }
    final uniqueSpans = uniqueSpanMap.values.toList()
      ..sort((a, b) => a.from.compareTo(b.from));

    if (uniqueSpans.length <= 1) return uniqueSpans;

    // 2. 여러 세부 델타를 포괄하는 대형 매크로/집계 델타(전체 세션 단일 델타 등) 제거
    final result = <DistDelta>[];
    for (final current in uniqueSpans) {
      final contained = uniqueSpans.where((other) =>
          other != current &&
          !other.from.isBefore(current.from) &&
          !other.to.isAfter(current.to) &&
          (other.from.isAfter(current.from) || other.to.isBefore(current.to))).toList();

      if (contained.isNotEmpty) {
        final containedMeters =
            contained.fold<double>(0, (s, d) => s + d.meters);
        if (containedMeters > 0) {
          // 세부 델타들이 존재하므로 매크로 집계 델타는 제외
          continue;
        }
      }
      result.add(current);
    }

    // 3. 겹치는 시간 구간의 부분 델타 비례 조정
    final nonOverlapping = <DistDelta>[];
    for (final d in result) {
      if (nonOverlapping.isEmpty) {
        nonOverlapping.add(d);
        continue;
      }
      final prev = nonOverlapping.last;
      if (!d.from.isBefore(prev.to)) {
        nonOverlapping.add(d);
      } else {
        final overlapMs = prev.to.difference(d.from).inMilliseconds;
        final dSpanMs = d.to.difference(d.from).inMilliseconds;
        if (dSpanMs > overlapMs && d.to.isAfter(prev.to)) {
          final nonOverlapSpanMs = d.to.difference(prev.to).inMilliseconds;
          final nonOverlapMeters = d.meters * (nonOverlapSpanMs / dSpanMs);
          if (nonOverlapMeters > 0) {
            nonOverlapping.add(DistDelta(
              from: prev.to,
              to: d.to,
              meters: nonOverlapMeters,
            ));
          }
        }
      }
    }

    return nonOverlapping;
  }

  /// 중복되거나 시간대가 겹치는 WORKOUT 레코드들을 우선순위에 따라 단일 세션으로 정리.
  /// (동일 시작/종료 시각, 또는 겹치는 시간 구간의 워크아웃)
  static List<(HealthDataPoint, WorkoutHealthValue)> deduplicateWorkouts(
    List<(HealthDataPoint, WorkoutHealthValue)> workouts,
  ) {
    if (workouts.length <= 1) return workouts;

    final sorted = List<(HealthDataPoint, WorkoutHealthValue)>.from(workouts)
      ..sort((a, b) {
        final cmp = a.$1.dateFrom.compareTo(b.$1.dateFrom);
        if (cmp != 0) return cmp;
        final durA = a.$1.dateTo.difference(a.$1.dateFrom).inMilliseconds;
        final durB = b.$1.dateTo.difference(b.$1.dateFrom).inMilliseconds;
        return durB.compareTo(durA);
      });

    final accepted = <(HealthDataPoint, WorkoutHealthValue)>[];

    for (final candidate in sorted) {
      final (candPoint, _) = candidate;
      int overlappingIdx = -1;

      for (var i = 0; i < accepted.length; i++) {
        final (accPoint, _) = accepted[i];
        final overlapStart = candPoint.dateFrom.isAfter(accPoint.dateFrom)
            ? candPoint.dateFrom
            : accPoint.dateFrom;
        final overlapEnd = candPoint.dateTo.isBefore(accPoint.dateTo)
            ? candPoint.dateTo
            : accPoint.dateTo;
        if (overlapEnd.isAfter(overlapStart)) {
          overlappingIdx = i;
          break;
        }
      }

      if (overlappingIdx == -1) {
        accepted.add(candidate);
      } else {
        final existing = accepted[overlappingIdx];
        if (compareWorkoutScore(candidate, existing) > 0) {
          accepted[overlappingIdx] = candidate;
        }
      }
    }

    return accepted..sort((a, b) => a.$1.dateFrom.compareTo(b.$1.dateFrom));
  }

  /// WORKOUT 우선순위 평가: Samsung Health 출처 > 유효한 총거리 > 소요 시간 > 상세 지표
  static int compareWorkoutScore(
    (HealthDataPoint, WorkoutHealthValue) a,
    (HealthDataPoint, WorkoutHealthValue) b,
  ) {
    final (pointA, valA) = a;
    final (pointB, valB) = b;

    final aIsSamsung = pointA.sourceId.contains('shealth') ||
        pointA.sourceId.contains('samsung') ||
        pointA.sourceName.toLowerCase().contains('samsung');
    final bIsSamsung = pointB.sourceId.contains('shealth') ||
        pointB.sourceId.contains('samsung') ||
        pointB.sourceName.toLowerCase().contains('samsung');
    if (aIsSamsung && !bIsSamsung) return 1;
    if (!aIsSamsung && bIsSamsung) return -1;

    final distA = valA.totalDistance?.toDouble() ?? 0.0;
    final distB = valB.totalDistance?.toDouble() ?? 0.0;
    if (distA > 0 && distB <= 0) return 1;
    if (distA <= 0 && distB > 0) return -1;
    if ((distA - distB).abs() > 10.0) {
      return distA > distB ? 1 : -1;
    }

    final durA = pointA.dateTo.difference(pointA.dateFrom).inSeconds;
    final durB = pointB.dateTo.difference(pointB.dateFrom).inSeconds;
    if ((durA - durB).abs() > 10) {
      return durA > durB ? 1 : -1;
    }

    final metricsA = (valA.totalEnergyBurned != null ? 1 : 0) +
        (valA.totalSteps != null ? 1 : 0);
    final metricsB = (valB.totalEnergyBurned != null ? 1 : 0) +
        (valB.totalSteps != null ? 1 : 0);
    if (metricsA != metricsB) return metricsA > metricsB ? 1 : -1;

    return 0;
  }

  /// RunSession 목록에서 동일하거나 시간대가 겹치는 세션을 우선순위에 따라 단일 세션으로 정리.
  static List<RunSession> deduplicateSessions(List<RunSession> sessions) {
    if (sessions.length <= 1) return sessions;

    final sorted = List<RunSession>.from(sessions)
      ..sort((a, b) {
        final cmp = a.startTime.compareTo(b.startTime);
        if (cmp != 0) return cmp;
        return b.durationSec.compareTo(a.durationSec);
      });

    final accepted = <RunSession>[];

    for (final candidate in sorted) {
      int overlappingIdx = -1;

      for (var i = 0; i < accepted.length; i++) {
        final acc = accepted[i];
        final overlapStart = candidate.startTime.isAfter(acc.startTime)
            ? candidate.startTime
            : acc.startTime;
        final overlapEnd = candidate.endTime.isBefore(acc.endTime)
            ? candidate.endTime
            : acc.endTime;
        if (overlapEnd.isAfter(overlapStart)) {
          overlappingIdx = i;
          break;
        }
      }

      if (overlappingIdx == -1) {
        accepted.add(candidate);
      } else {
        final existing = accepted[overlappingIdx];
        if (compareSessionScore(candidate, existing) > 0) {
          accepted[overlappingIdx] = candidate;
        }
      }
    }

    return accepted..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  /// RunSession 우선순위 평가: Samsung Health 출처 > 거리 > 소요 시간 > 상세 지표
  static int compareSessionScore(RunSession a, RunSession b) {
    final aIsSamsung = a.sourceName.toLowerCase().contains('samsung') ||
        a.sourceName.contains('shealth');
    final bIsSamsung = b.sourceName.toLowerCase().contains('samsung') ||
        b.sourceName.contains('shealth');
    if (aIsSamsung && !bIsSamsung) return 1;
    if (!aIsSamsung && bIsSamsung) return -1;

    if (a.distanceM > 0 && b.distanceM <= 0) return 1;
    if (a.distanceM <= 0 && b.distanceM > 0) return -1;
    if ((a.distanceM - b.distanceM).abs() > 10.0) {
      return a.distanceM > b.distanceM ? 1 : -1;
    }

    if ((a.durationSec - b.durationSec).abs() > 10) {
      return a.durationSec > b.durationSec ? 1 : -1;
    }

    final scoreA = (a.avgHr != null ? 1 : 0) +
        (a.steps != null ? 1 : 0) +
        (a.calories != null ? 1 : 0) +
        (a.splits.isNotEmpty ? 1 : 0) +
        (a.laps.isNotEmpty ? 1 : 0);
    final scoreB = (b.avgHr != null ? 1 : 0) +
        (b.steps != null ? 1 : 0) +
        (b.calories != null ? 1 : 0) +
        (b.splits.isNotEmpty ? 1 : 0) +
        (b.laps.isNotEmpty ? 1 : 0);

    return scoreA.compareTo(scoreB);
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
      final overlapMs = overlapEnd.difference(overlapStart).inMilliseconds;
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
  /// 삼성헬스처럼 세션 전체를 하나의 DISTANCE_DELTA로 내보내는 경우에는
  /// 시간 비례 보간이 모든 km를 같은 페이스로 꾸며내므로 스플릿을 만들지 않는다.
  static List<Split> computeSplits(
    DateTime sessionStart,
    List<DistDelta> deltas,
    List<HrSample> hrSamples,
  ) {
    if (deltas.length < 2) return const [];

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
  static List<HrSample> downsampleHr(List<HrSample> samples, Duration bucket) {
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
        .where(
          (p) =>
              !p.dateTo.isBefore(sessionStart) &&
              !p.dateFrom.isAfter(sessionEnd) &&
              sameSource(
                p.sourceId,
                workoutSourceId,
                dataSourceName: p.sourceName,
                workoutSourceName: workoutSourceName,
              ) &&
              p.value is NumericHealthValue,
        )
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
    final rawDeltas = allDistPoints
        .where(
          (p) =>
              !p.dateTo.isBefore(sessionStart) &&
              !p.dateFrom.isAfter(sessionEnd) &&
              sameSource(
                p.sourceId,
                workoutSourceId,
                dataSourceName: p.sourceName,
                workoutSourceName: workoutSourceName,
              ) &&
              p.value is NumericHealthValue,
        )
        .map(
          (p) => DistDelta(
            from: p.dateFrom,
            to: p.dateTo,
            meters: (p.value as NumericHealthValue).numericValue.toDouble(),
          ),
        )
        .toList();
    return deduplicateDistanceDeltas(rawDeltas);
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
        .where(
          (p) =>
              !p.dateTo.isBefore(sessionStart) &&
              !p.dateFrom.isAfter(sessionEnd) &&
              sameSource(
                p.sourceId,
                workoutSourceId,
                dataSourceName: p.sourceName,
                workoutSourceName: workoutSourceName,
              ) &&
              p.value is NumericHealthValue,
        )
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
        .where(
          (p) =>
              !p.dateTo.isBefore(sessionStart) &&
              !p.dateFrom.isAfter(sessionEnd) &&
              sameSource(
                p.sourceId,
                workoutSourceId,
                dataSourceName: p.sourceName,
                workoutSourceName: workoutSourceName,
              ) &&
              p.value is NumericHealthValue,
        )
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
    // 삼성헬스 totalDistance와 Health Connect deltaSum 중 유효한 세션 실측치 선택
    // totalDistance가 4.39km, deltaSum이 4.07km 등으로 약간 다를 때, deltaSum이 유효하면 GPS/이동 델타 합(deltaSum)을 우선 적용
    final distanceM = deltaSum > 0
        ? deltaSum
        : ((workoutValue.totalDistance?.toDouble() ?? 0) > 0
            ? workoutValue.totalDistance!.toDouble()
            : 0.0);

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
