import 'package:health/health.dart';

import '../models/run_session.dart';

/// Health Connect에서 러닝 세션을 읽어 RunSession으로 변환하는 서비스.
///
/// 삼성헬스 → Health Connect 동기화가 활성화되어 있어야 한다
/// (삼성헬스 설정 > 헬스 커넥트 > 데이터 동기화 켜기).
class HealthService {
  final Health _health = Health();

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

  /// 30일 이전 과거 데이터 읽기 권한 (READ_HEALTH_DATA_HISTORY).
  /// 기기가 미지원하면 false — 이 경우 30일 범위만 조회 가능.
  Future<bool> requestHistoryPermission() async {
    if (!await _health.isHealthDataHistoryAvailable()) return false;
    if (await _health.isHealthDataHistoryAuthorized()) return true;
    return _health.requestHealthDataHistoryAuthorization();
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
      if (!value.workoutActivityType.name.contains('RUNNING')) continue;

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
      splits: computeSplits(start, deltas, hrSamples),
      hrSeries: downsampleHr(hrSamples, const Duration(minutes: 1)),
      sourceName: point.sourceName,
    );
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
