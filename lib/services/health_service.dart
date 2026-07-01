import 'package:flutter/services.dart';
import 'package:health/health.dart';

import '../models/run_session.dart';

/// Health Connect에서 러닝 세션을 읽어 RunSession으로 변환하는 서비스.
///
/// 삼성헬스 → Health Connect 동기화가 활성화되어 있어야 한다
/// (삼성헬스 설정 > 헬스 커넥트 > 데이터 동기화 켜기).
class HealthService {
  final Health _health = Health();

  /// health 패키지 미지원 데이터(세그먼트/고도/VO2max)용 네이티브 채널
  static const _extra = MethodChannel('runlog/hc_extra');

  static const List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.STEPS,
  ];

  Future<void> configure() => _health.configure();

  /// 읽기 권한 요청. Health Connect 미설치 등은 예외로 전파된다.
  Future<bool> requestPermissions() async {
    final permissions =
        List.filled(_types.length, HealthDataAccess.READ, growable: false);
    final has =
        await _health.hasPermissions(_types, permissions: permissions);
    if (has == true) return true;
    return _health.requestAuthorization(_types, permissions: permissions);
  }

  /// 고도·VO2max 읽기 권한 (네이티브 컨트랙트). 실패해도 동기화는 계속.
  Future<bool> requestExtraPermissions() async {
    try {
      return await _extra.invokeMethod<bool>('requestExtraPermissions') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// VO2max 시계열 (체력 추세용). 삼성헬스가 동기화 안 하면 빈 리스트.
  Future<List<(DateTime, double)>> fetchVo2Series(
      DateTime start, DateTime end) async {
    try {
      final raw = await _extra.invokeMethod<List<dynamic>>(
        'getVo2MaxSeries',
        {
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
        },
      );
      return (raw ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => (
                DateTime.fromMillisecondsSinceEpoch(
                    (m['timeMs'] as num).toInt()),
                (m['value'] as num).toDouble(),
              ))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
    } catch (_) {
      return const [];
    }
  }

  Future<List<RunSegment>> _fetchSegments(String uuid, DateTime start,
      DateTime end, List<DistDelta> deltas, List<HrSample> hrSamples) async {
    try {
      final raw = await _extra.invokeMethod<List<dynamic>>(
        'getSessionDetails',
        {
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
        },
      );
      for (final s in raw ?? []) {
        final session = Map<String, dynamic>.from(s as Map);
        if (session['uuid'] != uuid) continue;
        return (session['segments'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) {
          final segStart = DateTime.fromMillisecondsSinceEpoch(
              (m['startMs'] as num).toInt());
          final segEnd = DateTime.fromMillisecondsSinceEpoch(
              (m['endMs'] as num).toInt());
          return RunSegment(
            startTime: segStart,
            endTime: segEnd,
            type: m['type'] as String? ?? 'unknown',
            distanceM: distanceBetween(deltas, segStart, segEnd),
            avgHr: _avgHrBetween(hrSamples, segStart, segEnd),
          );
        }).toList();
      }
      return const [];
    } catch (_) {
      return const []; // 세그먼트 미지원/미제공 — 1km 스플릿으로 대체 표시
    }
  }

  Future<double> _fetchElevation(DateTime start, DateTime end) async {
    try {
      return await _extra.invokeMethod<double>(
            'getElevationGained',
            {
              'startMs': start.millisecondsSinceEpoch,
              'endMs': end.millisecondsSinceEpoch,
            },
          ) ??
          0;
    } catch (_) {
      return 0;
    }
  }

  /// [from]~[to] 구간의 거리(미터) — 델타가 경계에 걸치면 시간 비례 배분
  static double distanceBetween(
      List<DistDelta> deltas, DateTime from, DateTime to) {
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

  /// 30일 이전 과거 데이터 읽기 권한 (READ_HEALTH_DATA_HISTORY).
  /// 기기가 미지원하면 false — 이 경우 30일 범위만 조회 가능.
  Future<bool> requestHistoryPermission() async {
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    if (await _health.isHealthDataHistoryAuthorized()) return true;
    return _health.requestHealthDataHistoryAuthorization();
  }

  /// 진단용: health 패키지를 거치지 않고 Health Connect SDK를 직접 호출해
  /// 같은 구간의 세션 목록을 가져온다. health 패키지 자체의 누락 문제인지
  /// Health Connect 권한/가시성 문제인지 구분하기 위한 대조군.
  Future<List<Map<String, String>>> debugNativeSessions(DateTime since) async {
    try {
      final raw = await _extra.invokeMethod<List<dynamic>>(
        'getRawSessions',
        {
          'startMs': since.millisecondsSinceEpoch,
          'endMs': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return (raw ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => {
                'exerciseType': '${m['exerciseType']}',
                'title': '${m['title']}',
                'start': DateTime.fromMillisecondsSinceEpoch(
                        (m['startMs'] as num).toInt())
                    .toIso8601String(),
                'end': DateTime.fromMillisecondsSinceEpoch(
                        (m['endMs'] as num).toInt())
                    .toIso8601String(),
                'dataOrigin': '${m['dataOrigin']}',
              })
          .toList();
    } catch (e) {
      return [
        {'error': '$e'}
      ];
    }
  }

  /// 진단용: Health Connect Training Plans API의 계획된 운동
  /// (PlannedExerciseSessionRecord)을 직접 읽는다. 삼성헬스가 인터벌
  /// 프로그램을 이 타입으로 기록하기 시작했다면 ExerciseSessionRecord
  /// 조회에서는 완전히 누락된다.
  Future<List<Map<String, String>>> debugPlannedSessions(
      DateTime since) async {
    try {
      final raw = await _extra.invokeMethod<List<dynamic>>(
        'getPlannedSessions',
        {
          'startMs': since.millisecondsSinceEpoch,
          'endMs': DateTime.now().millisecondsSinceEpoch,
        },
      );
      return (raw ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .map((m) => {
                'title': '${m['title']}',
                'start': DateTime.fromMillisecondsSinceEpoch(
                        (m['startMs'] as num).toInt())
                    .toIso8601String(),
                'end': DateTime.fromMillisecondsSinceEpoch(
                        (m['endMs'] as num).toInt())
                    .toIso8601String(),
                'completionUuid': '${m['completionUuid']}',
                'dataOrigin': '${m['dataOrigin']}',
              })
          .toList();
    } catch (e) {
      return [
        {'error': '$e'}
      ];
    }
  }

  /// 진단용: 필터링 없이 원본 WORKOUT 레코드의 타입/시각/출처를 그대로 반환.
  /// 동기화 누락 원인 파악(예: 예상치 못한 workoutActivityType) 확인용.
  Future<List<Map<String, String>>> debugRawWorkouts(DateTime since) async {
    final now = DateTime.now();
    final workouts = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: since,
      endTime: now,
    );
    return workouts.map((point) {
      final value = point.value;
      return {
        'type': value is WorkoutHealthValue
            ? value.workoutActivityType.name
            : value.runtimeType.toString(),
        'start': point.dateFrom.toIso8601String(),
        'end': point.dateTo.toIso8601String(),
        'source': point.sourceName,
      };
    }).toList();
  }

  /// [since] 이후의 러닝 세션을 가져온다.
  /// Health Connect는 최초 권한 시점 기준 과거 30일 이전 데이터 조회가 제한되므로
  /// 최초 동기화 범위도 30일로 잡는다 (PRD 3.1 주의사항).
  Future<List<RunSession>> fetchRuns({DateTime? since}) async {
    final now = DateTime.now();
    final start = since ?? now.subtract(const Duration(days: 30));

    final workouts = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: now,
    );

    final runs = <RunSession>[];
    for (final point in workouts) {
      final value = point.value;
      if (value is! WorkoutHealthValue) continue;
      // 삼성헬스가 달리기/걷기 인터벌 세션을 세션 레벨에서 RUNNING이 아닌
      // HIGH_INTENSITY_INTERVAL_TRAINING으로 태깅하는 경우가 있어 함께 허용
      // (23일 인터벌 러닝 프로그램 기록이 이 타입으로 들어옴).
      final typeName = value.workoutActivityType.name;
      final isRunLike = typeName.contains('RUNNING') ||
          typeName == 'HIGH_INTENSITY_INTERVAL_TRAINING';
      if (!isRunLike) continue;

      runs.add(await _buildSession(point, value));
    }
    return runs;
  }

  Future<RunSession> _buildSession(
      HealthDataPoint point, WorkoutHealthValue value) async {
    final start = point.dateFrom;
    final end = point.dateTo;

    // 세션 구간의 심박 시계열
    final hrPoints = await _health.getHealthDataFromTypes(
      types: [HealthDataType.HEART_RATE],
      startTime: start,
      endTime: end,
    );
    final hrSamples = hrPoints
        .where((p) => p.value is NumericHealthValue)
        .map((p) => HrSample(
              time: p.dateFrom,
              bpm: (p.value as NumericHealthValue).numericValue.toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));

    // 세션 구간의 거리 델타 (스플릿 산출용)
    final distPoints = await _health.getHealthDataFromTypes(
      types: [HealthDataType.DISTANCE_DELTA],
      startTime: start,
      endTime: end,
    );
    final deltas = distPoints
        .where((p) => p.value is NumericHealthValue)
        .map((p) => DistDelta(
              from: p.dateFrom,
              to: p.dateTo,
              meters:
                  (p.value as NumericHealthValue).numericValue.toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.from.compareTo(b.from));

    final deltaSum = deltas.fold<double>(0, (sum, d) => sum + d.meters);
    final distanceM =
        (value.totalDistance?.toDouble() ?? 0) > 0
            ? value.totalDistance!.toDouble()
            : deltaSum;

    double? calories = value.totalEnergyBurned?.toDouble();
    if (calories == null || calories == 0) {
      final calPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.TOTAL_CALORIES_BURNED],
        startTime: start,
        endTime: end,
      );
      final calSum = calPoints
          .where((p) => p.value is NumericHealthValue)
          .fold<double>(
              0,
              (sum, p) =>
                  sum + (p.value as NumericHealthValue).numericValue);
      calories = calSum > 0 ? calSum : null;
    }

    // 케이던스(걸음) — 삼성헬스가 미제공하면 null
    final steps = (await _sumNumeric(HealthDataType.STEPS, start, end)).round();

    // 인터벌 세그먼트(운동/회복)·상승고도 — 네이티브 채널
    final segments =
        await _fetchSegments(point.uuid, start, end, deltas, hrSamples);
    final elevation = await _fetchElevation(start, end);

    final avgHr = hrSamples.isEmpty
        ? null
        : hrSamples.fold<double>(0, (s, h) => s + h.bpm) / hrSamples.length;
    final maxHr = hrSamples.isEmpty
        ? null
        : hrSamples.map((h) => h.bpm).reduce((a, b) => a > b ? a : b);

    return RunSession(
      id: point.uuid,
      startTime: start,
      endTime: end,
      distanceM: distanceM,
      durationSec: end.difference(start).inSeconds,
      avgHr: avgHr,
      maxHr: maxHr,
      calories: calories,
      steps: steps > 0 ? steps : null,
      elevationM: elevation > 0 ? elevation : null,
      segments: segments,
      splits: computeSplits(start, deltas, hrSamples),
      hrSeries: downsampleHr(hrSamples, const Duration(minutes: 1)),
      sourceName: point.sourceName,
    );
  }

  Future<double> _sumNumeric(
      HealthDataType type, DateTime start, DateTime end) async {
    try {
      final points = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
      return points.where((p) => p.value is NumericHealthValue).fold<double>(
          0, (sum, p) => sum + (p.value as NumericHealthValue).numericValue);
    } catch (_) {
      return 0; // 타입 미지원 기기에서도 동기화는 계속
    }
  }

  /// 거리 델타 시계열로 km별 스플릿 산출.
  /// 1km 경계를 넘는 델타 구간은 선형 보간으로 통과 시각을 추정한다.
  /// 삼성헬스가 델타를 안 쓰는 경우 빈 리스트가 되어 스플릿 미표시 (리스크 2).
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
            Duration(milliseconds: (spanSec * 1000 * frac).round()));
        final paceSec = crossTime.difference(lastCross).inSeconds;
        splits.add(Split(
          km: nextKm.toDouble(),
          paceSecPerKm: paceSec,
          avgHr: _avgHrBetween(hrSamples, lastCross, crossTime),
        ));
        lastCross = crossTime;
        nextKm++;
      }
    }

    // 마지막 부분 km (300m 이상일 때만 표시, 환산 페이스)
    final remainM = cumM - (nextKm - 1) * 1000;
    if (remainM >= 300) {
      final remainSec = deltas.last.to.difference(lastCross).inSeconds;
      splits.add(Split(
        km: double.parse((cumM / 1000).toStringAsFixed(2)),
        paceSecPerKm: (remainSec / (remainM / 1000)).round(),
        avgHr: _avgHrBetween(hrSamples, lastCross, deltas.last.to),
      ));
    }
    return splits;
  }

  static double? _avgHrBetween(
      List<HrSample> samples, DateTime from, DateTime to) {
    final inRange = samples
        .where((h) => !h.time.isBefore(from) && !h.time.isAfter(to))
        .toList();
    if (inRange.isEmpty) return null;
    return inRange.fold<double>(0, (s, h) => s + h.bpm) / inRange.length;
  }

  /// Firestore 1MB 문서 제한 대비 다운샘플링 (PRD 5). 로컬 저장도 동일 적용.
  static List<HrSample> downsampleHr(
      List<HrSample> samples, Duration bucket) {
    if (samples.isEmpty) return const [];
    final out = <HrSample>[];
    DateTime bucketStart = samples.first.time;
    final acc = <double>[];
    for (final s in samples) {
      if (s.time.difference(bucketStart) >= bucket) {
        out.add(HrSample(
          time: bucketStart,
          bpm: acc.reduce((a, b) => a + b) / acc.length,
        ));
        bucketStart = s.time;
        acc.clear();
      }
      acc.add(s.bpm);
    }
    if (acc.isNotEmpty) {
      out.add(HrSample(
        time: bucketStart,
        bpm: acc.reduce((a, b) => a + b) / acc.length,
      ));
    }
    return out;
  }
}

/// Health Connect DISTANCE_DELTA 1건 (테스트에서 직접 생성 가능하도록 공개)
class DistDelta {
  final DateTime from;
  final DateTime to;
  final double meters;
  const DistDelta({required this.from, required this.to, required this.meters});
}
