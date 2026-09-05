import 'package:health/health.dart';

import '../models/run_session.dart';
import 'health/health_data_matcher.dart';
import 'health/native_health_channel.dart';

export 'health/health_data_matcher.dart' show DistDelta, HealthDataMatcher;
export 'health/native_health_channel.dart'
    show NativeHealthChannel, NativeSessionDetail, NativeRawSegment, NativeRawLap;

/// Health Connect에서 러닝 세션을 읽어 RunSession으로 변환하는 서비스.
///
/// 삼성헬스 → Health Connect 동기화가 활성화되어 있어야 한다
/// (삼성헬스 설정 > 헬스 커넥트 > 데이터 동기화 켜기).
class HealthService {
  final Health _health;
  final NativeHealthChannel _nativeChannel;

  static const List<HealthDataType> _types = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_DELTA,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.STEPS,
  ];

  HealthService({
    Health? health,
    NativeHealthChannel? nativeChannel,
  })  : _health = health ?? Health(),
        _nativeChannel = nativeChannel ?? const NativeHealthChannel();

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
  Future<bool> requestExtraPermissions() =>
      _nativeChannel.requestExtraPermissions();

  /// VO2max 시계열 (체력 추세용). 삼성헬스가 동기화 안 하면 빈 리스트.
  Future<List<(DateTime, double)>> fetchVo2Series(
    DateTime start,
    DateTime end,
  ) =>
      _nativeChannel.fetchVo2Series(start, end);

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
  Future<List<Map<String, String>>> debugNativeSessions(DateTime since) =>
      _nativeChannel.debugRawSessions(since);

  /// 진단용: Health Connect Training Plans API의 계획된 운동
  /// (PlannedExerciseSessionRecord)을 직접 읽는다.
  Future<List<Map<String, String>>> debugPlannedSessions(DateTime since) =>
      _nativeChannel.debugPlannedSessions(since);

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
  ///
  /// 성능 최적화:
  /// 세션별로 개별 Health Connect 쿼리를 수십~수백 번 반복(Sequential)하지 않고,
  /// 1) WORKOUT 목록을 먼저 조회한 후
  /// 2) 세션들의 전체 기간을 아우르는 단일 Bulk 쿼리로 심박/거리/칼로리/걸음 데이터를 병렬 획득하고
  /// 3) In-memory 상에서 시간 구간 및 출처 매칭을 수행하여 고속으로 세션을 조립한다.
  Future<List<RunSession>> fetchRuns({DateTime? since}) async {
    final now = DateTime.now();
    final start = since ?? now.subtract(const Duration(days: 30));

    final workouts = await _health.getHealthDataFromTypes(
      types: [HealthDataType.WORKOUT],
      startTime: start,
      endTime: now,
    );

    final runWorkouts = <(HealthDataPoint, WorkoutHealthValue)>[];
    for (final point in workouts) {
      final value = point.value;
      if (value is! WorkoutHealthValue) continue;
      final typeName = value.workoutActivityType.name;
      final isRunLike = typeName.contains('RUNNING') ||
          typeName == 'HIGH_INTENSITY_INTERVAL_TRAINING';
      if (!isRunLike) continue;

      runWorkouts.add((point, value));
    }

    if (runWorkouts.isEmpty) return const [];

    // 전체 러닝 세션의 최소 시작 시각과 최대 종료 시각
    var bulkStart = runWorkouts.first.$1.dateFrom;
    var bulkEnd = runWorkouts.first.$1.dateTo;
    for (final (point, _) in runWorkouts) {
      if (point.dateFrom.isBefore(bulkStart)) bulkStart = point.dateFrom;
      if (point.dateTo.isAfter(bulkEnd)) bulkEnd = point.dateTo;
    }

    // 기간 단위 Bulk 쿼리 병렬 실행 (IPC 호출 최소화)
    final bulkResults = await Future.wait([
      _getBulkHealthData(HealthDataType.HEART_RATE, bulkStart, bulkEnd),
      _getBulkHealthData(HealthDataType.DISTANCE_DELTA, bulkStart, bulkEnd),
      _getBulkHealthData(HealthDataType.TOTAL_CALORIES_BURNED, bulkStart, bulkEnd),
      _getBulkHealthData(HealthDataType.STEPS, bulkStart, bulkEnd),
      _nativeChannel.fetchSessionDetailsMap(bulkStart, bulkEnd),
    ]);

    final hrPoints = bulkResults[0] as List<HealthDataPoint>;
    final distPoints = bulkResults[1] as List<HealthDataPoint>;
    final calPoints = bulkResults[2] as List<HealthDataPoint>;
    final stepsPoints = bulkResults[3] as List<HealthDataPoint>;
    final nativeDetailsMap =
        bulkResults[4] as Map<String, NativeSessionDetail>;

    // 각 세션별 고도 데이터 병렬 조회
    final elevationFutures = runWorkouts.map((w) {
      return _nativeChannel.fetchElevation(
        w.$1.dateFrom,
        w.$1.dateTo,
        w.$1.sourceId,
      );
    }).toList();
    final elevations = await Future.wait(elevationFutures);

    // In-memory 매칭으로 RunSession 조립
    final runs = <RunSession>[];
    for (var i = 0; i < runWorkouts.length; i++) {
      final (point, value) = runWorkouts[i];
      final nativeDetail = nativeDetailsMap[point.uuid];
      final elevation = elevations[i];

      final session = HealthDataMatcher.buildRunSession(
        workoutPoint: point,
        workoutValue: value,
        allHrPoints: hrPoints,
        allDistPoints: distPoints,
        allCalPoints: calPoints,
        allStepsPoints: stepsPoints,
        nativeDetail: nativeDetail,
        elevation: elevation,
      );
      runs.add(session);
    }
    return runs;
  }

  Future<List<HealthDataPoint>> _getBulkHealthData(
    HealthDataType type,
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _health.getHealthDataFromTypes(
        types: [type],
        startTime: start,
        endTime: end,
      );
    } catch (_) {
      return const [];
    }
  }

  // --- 기존 코드 및 테스트와의 100% 하위 호환성을 위한 위임 메서드 ---

  static double distanceBetween(
    List<DistDelta> deltas,
    DateTime from,
    DateTime to,
  ) =>
      HealthDataMatcher.distanceBetween(deltas, from, to);

  static List<Split> computeSplits(
    DateTime sessionStart,
    List<DistDelta> deltas,
    List<HrSample> hrSamples,
  ) =>
      HealthDataMatcher.computeSplits(sessionStart, deltas, hrSamples);

  static bool sameSource(
    String dataSourceId,
    String workoutSourceId, {
    String dataSourceName = '',
    String workoutSourceName = '',
  }) =>
      HealthDataMatcher.sameSource(
        dataSourceId,
        workoutSourceId,
        dataSourceName: dataSourceName,
        workoutSourceName: workoutSourceName,
      );

  static List<HrSample> downsampleHr(
    List<HrSample> samples,
    Duration bucket,
  ) =>
      HealthDataMatcher.downsampleHr(samples, bucket);
}
