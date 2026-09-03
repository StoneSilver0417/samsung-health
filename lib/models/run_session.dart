import 'dart:convert';

/// km 단위 스플릿 (하위 호환 유지).
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

/// 워치 실제 랩 (Health Connect ExerciseLap).
class RunLap {
  final int lapNumber;
  final DateTime startTime;
  final DateTime endTime;
  final double distanceM;
  final double? avgHr;

  const RunLap({
    required this.lapNumber,
    required this.startTime,
    required this.endTime,
    required this.distanceM,
    this.avgHr,
  });

  int get durationSec => endTime.difference(startTime).inSeconds;
  double get distanceKm => distanceM / 1000;
  int get paceSecPerKm =>
      distanceM >= 30 ? (durationSec / (distanceM / 1000)).round() : 0;

  Map<String, dynamic> toJson() => {
        'num': lapNumber,
        's': startTime.millisecondsSinceEpoch,
        'e': endTime.millisecondsSinceEpoch,
        'distM': distanceM,
        if (avgHr != null) 'avgHr': avgHr,
      };

  factory RunLap.fromJson(Map<String, dynamic> json) => RunLap(
        lapNumber: (json['num'] as num?)?.toInt() ?? 1,
        startTime:
            DateTime.fromMillisecondsSinceEpoch((json['s'] as num).toInt()),
        endTime:
            DateTime.fromMillisecondsSinceEpoch((json['e'] as num).toInt()),
        distanceM: (json['distM'] as num?)?.toDouble() ?? 0,
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
  final List<RunLap> laps;
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
    this.laps = const [],
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

  /// 평균 보폭 (cm). 거리와 걸음 수 있을 때 산출.
  double? get strideCm => (distanceM > 0 && steps != null && steps! > 0)
      ? (distanceM / steps! * 100)
      : null;

  /// 심박수 드리프트 (Cardiac Drift, %).
  /// 전반부(50%) 평균 심박 vs 후반부(50%) 평균 심박 상승률.
  /// 심박 샘플 4개 이상일 때 산출.
  double? get cardiacDriftPct {
    if (hrSeries.length < 4) return null;
    final mid = hrSeries.length ~/ 2;
    final firstHalf = hrSeries.sublist(0, mid);
    final secondHalf = hrSeries.sublist(mid);
    final avg1 =
        firstHalf.fold<double>(0, (s, h) => s + h.bpm) / firstHalf.length;
    final avg2 =
        secondHalf.fold<double>(0, (s, h) => s + h.bpm) / secondHalf.length;
    if (avg1 <= 0) return null;
    return ((avg2 - avg1) / avg1) * 100;
  }

  /// 유산소(Z1~Z3) vs 무산소(Z4~Z5) 비율 (%).
  ({double aerobicPct, double anaerobicPct})? get aerobicAnaerobicRatio {
    if (hrSeries.isEmpty) return null;
    final max = maxHr ?? 190.0;
    int aerobicCount = 0;
    int anaerobicCount = 0;
    for (final s in hrSeries) {
      final pct = s.bpm / max;
      if (pct < 0.8) {
        aerobicCount++;
      } else {
        anaerobicCount++;
      }
    }
    final total = hrSeries.length.toDouble();
    if (total == 0) return null;
    return (
      aerobicPct: (aerobicCount / total) * 100,
      anaerobicPct: (anaerobicCount / total) * 100,
    );
  }

  /// 훈련 부하 지수 (TRIMP 기반 점수).
  int get trainingLoadScore {
    if (durationSec <= 0) return 0;
    final durationMin = durationSec / 60.0;
    if (hrSeries.isNotEmpty) {
      final max = maxHr ?? 190.0;
      double weightedMinutes = 0;
      for (final s in hrSeries) {
        final pct = s.bpm / max;
        double weight;
        if (pct < 0.6) {
          weight = 1.0;
        } else if (pct < 0.7) {
          weight = 1.5;
        } else if (pct < 0.8) {
          weight = 2.2;
        } else if (pct < 0.9) {
          weight = 3.5;
        } else {
          weight = 5.0;
        }
        weightedMinutes += weight;
      }
      final avgWeight = weightedMinutes / hrSeries.length;
      return (durationMin * avgWeight).round();
    }
    return (durationMin * 2.0).round();
  }

  /// 권장 회복 시간 (시간).
  int get recommendedRecoveryHours {
    final load = trainingLoadScore;
    if (load < 30) return 12;
    if (load < 60) return 18;
    if (load < 100) return 24;
    if (load < 150) return 36;
    return 48;
  }

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
        'laps': laps.map((l) => l.toJson()).toList(),
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
        laps: (json['laps'] as List? ?? [])
            .map((e) => RunLap.fromJson(Map<String, dynamic>.from(e as Map)))
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
