import 'package:flutter/services.dart';

/// 네이티브 세그먼트/랩/걸음수 원본 DTO.
class NativeSessionDetail {
  final String uuid;
  final int? totalSteps;
  final List<NativeRawSegment> segments;
  final List<NativeRawLap> laps;

  const NativeSessionDetail({
    required this.uuid,
    this.totalSteps,
    this.segments = const [],
    this.laps = const [],
  });
}

class NativeRawSegment {
  final DateTime start;
  final DateTime end;
  final String type;

  const NativeRawSegment({
    required this.start,
    required this.end,
    required this.type,
  });
}

class NativeRawLap {
  final DateTime start;
  final DateTime end;
  final double lengthM;

  const NativeRawLap({
    required this.start,
    required this.end,
    required this.lengthM,
  });
}

/// health 패키지 미지원 데이터(세그먼트/고도/VO2max/걸음직독)를 다루는
/// 네이티브 MethodChannel ('runlog/hc_extra') 래퍼.
class NativeHealthChannel {
  static const MethodChannel _channel = MethodChannel('runlog/hc_extra');

  const NativeHealthChannel();

  /// 고도·VO2max 읽기 권한 요청
  Future<bool> requestExtraPermissions() async {
    try {
      return await _channel.invokeMethod<bool>('requestExtraPermissions') ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// VO2max 시계열 데이터 조회
  Future<List<(DateTime, double)>> fetchVo2Series(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
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
                  (m['timeMs'] as num).toInt(),
                ),
                (m['value'] as num).toDouble(),
              ))
          .toList()
        ..sort((a, b) => a.$1.compareTo(b.$1));
    } catch (_) {
      return const [];
    }
  }

  /// 기간 내 모든 세션의 상세(세그먼트, 랩, 직독 걸음) 정보를 `Map<uuid, NativeSessionDetail>` 형태로 일괄 조회
  Future<Map<String, NativeSessionDetail>> fetchSessionDetailsMap(
    DateTime start,
    DateTime end,
  ) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
        'getSessionDetails',
        {
          'startMs': start.millisecondsSinceEpoch,
          'endMs': end.millisecondsSinceEpoch,
        },
      );
      final result = <String, NativeSessionDetail>{};
      for (final s in raw ?? []) {
        final session = Map<String, dynamic>.from(s as Map);
        final uuid = session['uuid'] as String? ?? '';
        if (uuid.isEmpty) continue;

        final rawSegments = (session['segments'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) => NativeRawSegment(
                  start: DateTime.fromMillisecondsSinceEpoch(
                    (m['startMs'] as num).toInt(),
                  ),
                  end: DateTime.fromMillisecondsSinceEpoch(
                    (m['endMs'] as num).toInt(),
                  ),
                  type: m['type'] as String? ?? 'unknown',
                ))
            .toList();

        final rawLaps = (session['laps'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((m) => NativeRawLap(
                  start: DateTime.fromMillisecondsSinceEpoch(
                    (m['startMs'] as num).toInt(),
                  ),
                  end: DateTime.fromMillisecondsSinceEpoch(
                    (m['endMs'] as num).toInt(),
                  ),
                  lengthM: (m['lengthM'] as num?)?.toDouble() ?? 0.0,
                ))
            .toList();

        final totalSteps = (session['totalSteps'] as num?)?.toInt();

        result[uuid] = NativeSessionDetail(
          uuid: uuid,
          totalSteps: totalSteps,
          segments: rawSegments,
          laps: rawLaps,
        );
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  /// 세션 구간 상승 고도 조회
  Future<double> fetchElevation(
    DateTime start,
    DateTime end,
    String sourceId,
  ) async {
    try {
      return await _channel.invokeMethod<double>(
            'getElevationGained',
            {
              'startMs': start.millisecondsSinceEpoch,
              'endMs': end.millisecondsSinceEpoch,
              'sourceId': sourceId,
            },
          ) ??
          0.0;
    } catch (_) {
      return 0.0;
    }
  }

  /// 진단용: 원본 운동 세션 목록 조회
  Future<List<Map<String, String>>> debugRawSessions(DateTime since) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
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
                  (m['startMs'] as num).toInt(),
                ).toIso8601String(),
                'end': DateTime.fromMillisecondsSinceEpoch(
                  (m['endMs'] as num).toInt(),
                ).toIso8601String(),
                'dataOrigin': '${m['dataOrigin']}',
              })
          .toList();
    } catch (e) {
      return [
        {'error': '$e'}
      ];
    }
  }

  /// 진단용: PlannedExerciseSessionRecord 조회
  Future<List<Map<String, String>>> debugPlannedSessions(
    DateTime since,
  ) async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>(
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
                  (m['startMs'] as num).toInt(),
                ).toIso8601String(),
                'end': DateTime.fromMillisecondsSinceEpoch(
                  (m['endMs'] as num).toInt(),
                ).toIso8601String(),
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
}
