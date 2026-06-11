import 'dart:convert';

/// km 단위 스플릿. [km]은 누적 km 라벨(부분 km는 소수), [paceSecPerKm]은 해당 구간 환산 페이스.
class Split {
  final double km;
  final int paceSecPerKm;
  final double? avgHr;

  const Split({required this.km, required this.paceSecPerKm, this.avgHr});

  Map<String, dynamic> toJson() => {
        'km': km,
        'paceSecPerKm': paceSecPerKm,
        if (avgHr != null) 'avgHr': avgHr,
      };

  factory Split.fromJson(Map<String, dynamic> json) => Split(
        km: (json['km'] as num).toDouble(),
        paceSecPerKm: (json['paceSecPerKm'] as num).toInt(),
        avgHr: (json['avgHr'] as num?)?.toDouble(),
      );
}

/// 인터벌 운동/회복 세그먼트 (Health Connect ExerciseSegment).
/// type: running / walking / rest / pause / stretching / hiit / other / unknown
class RunSegment {
  final DateTime startTime;
  final DateTime endTime;
  final String type;
  final double distanceM;
  final double? avgHr;

  const RunSegment({
    required this.startTime,
    required this.endTime,
    required this.type,
    this.distanceM = 0,
    this.avgHr,
  });

  int get durationSec => endTime.difference(startTime).inSeconds;

  bool get isActive => type == 'running' || type == 'hiit';

  /// 구간 환산 페이스 (초/km). 거리가 거의 없으면 0.
  int get paceSecPerKm =>
      distanceM >= 30 ? (durationSec / (distanceM / 1000)).round() : 0;

  Map<String, dynamic> toJson() => {
        's': startTime.millisecondsSinceEpoch,
        'e': endTime.millisecondsSinceEpoch,
        'type': type,
        'distM': distanceM,
        if (avgHr != null) 'avgHr': avgHr,
      };

  factory RunSegment.fromJson(Map<String, dynamic> json) => RunSegment(
        startTime:
            DateTime.fromMillisecondsSinceEpoch((json['s'] as num).toInt()),
        endTime:
            DateTime.fromMillisecondsSinceEpoch((json['e'] as num).toInt()),
        type: json['type'] as String? ?? 'unknown',
        distanceM: (json['distM'] as num?)?.toDouble() ?? 0,
        avgHr: (json['avgHr'] as num?)?.toDouble(),
      );
}

/// 심박 샘플 (1분 단위 다운샘플링되어 저장됨)
class HrSample {
  final DateTime time;
  final double bpm;

  const HrSample({required this.time, required this.bpm});

  Map<String, dynamic> toJson() =>
      {'t': time.millisecondsSinceEpoch, 'bpm': bpm};

  factory HrSample.fromJson(Map<String, dynamic> json) => HrSample(
        time: DateTime.fromMillisecondsSinceEpoch((json['t'] as num).toInt()),
        bpm: (json['bpm'] as num).toDouble(),
      );
}

/// 러닝 세션 1회. id는 Health Connect 세션 UUID (dedupe 기준).
class RunSession {
  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceM;
  final int durationSec;
  final double? avgHr;
  final double? maxHr;
  final double? calories;
  final int? steps;
  final double? elevationM;
  final List<Split> splits;
  final List<RunSegment> segments;
  final List<HrSample> hrSeries;
  final String sourceName;

  const RunSession({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.distanceM,
    required this.durationSec,
    this.avgHr,
    this.maxHr,
    this.calories,
    this.steps,
    this.elevationM,
    this.splits = const [],
    this.segments = const [],
    this.hrSeries = const [],
    this.sourceName = '',
  });

  double get distanceKm => distanceM / 1000;

  /// 평균 페이스 (초/km). 거리 0이면 0.
  int get avgPaceSecPerKm =>
      distanceM > 0 ? (durationSec / (distanceM / 1000)).round() : 0;

  /// 평균 케이던스 (걸음/분). 걸음 데이터 없으면 null.
  double? get cadenceSpm => (steps != null && steps! > 0 && durationSec > 0)
      ? steps! / (durationSec / 60)
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'startTime': startTime.millisecondsSinceEpoch,
        'endTime': endTime.millisecondsSinceEpoch,
        'distanceM': distanceM,
        'durationSec': durationSec,
        if (avgHr != null) 'avgHr': avgHr,
        if (maxHr != null) 'maxHr': maxHr,
        if (calories != null) 'calories': calories,
        if (steps != null) 'steps': steps,
        if (elevationM != null) 'elevationM': elevationM,
        'splits': splits.map((s) => s.toJson()).toList(),
        'segments': segments.map((s) => s.toJson()).toList(),
        'hrSeries': hrSeries.map((h) => h.toJson()).toList(),
        'sourceName': sourceName,
      };

  factory RunSession.fromJson(Map<String, dynamic> json) => RunSession(
        id: json['id'] as String,
        startTime: DateTime.fromMillisecondsSinceEpoch(
            (json['startTime'] as num).toInt()),
        endTime: DateTime.fromMillisecondsSinceEpoch(
            (json['endTime'] as num).toInt()),
        distanceM: (json['distanceM'] as num).toDouble(),
        durationSec: (json['durationSec'] as num).toInt(),
        avgHr: (json['avgHr'] as num?)?.toDouble(),
        maxHr: (json['maxHr'] as num?)?.toDouble(),
        calories: (json['calories'] as num?)?.toDouble(),
        steps: (json['steps'] as num?)?.toInt(),
        elevationM: (json['elevationM'] as num?)?.toDouble(),
        splits: (json['splits'] as List? ?? [])
            .map((e) => Split.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        segments: (json['segments'] as List? ?? [])
            .map((e) =>
                RunSegment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        hrSeries: (json['hrSeries'] as List? ?? [])
            .map((e) => HrSample.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        sourceName: json['sourceName'] as String? ?? '',
      );

  String encode() => jsonEncode(toJson());

  factory RunSession.decode(String raw) =>
      RunSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
