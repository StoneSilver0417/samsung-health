/// 업적(배지) 정의 — NRC 스타일 카테고리별 배지 (PRD 4.3)
enum BadgeCategory {
  distance('거리'),
  total('누적 거리'),
  time('시간'),
  streak('꾸준함'),
  special('스페셜');

  final String label;
  const BadgeCategory(this.label);
}

class BadgeDef {
  final String id;
  final String title;
  final String description;
  final BadgeCategory category;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
  });

  String get assetPath => 'assets/badges/$id.png';
}

/// 획득한 업적 기록
class EarnedBadge {
  final String badgeId;
  final DateTime earnedAt;
  final String? runId;

  const EarnedBadge({required this.badgeId, required this.earnedAt, this.runId});

  Map<String, dynamic> toJson() => {
        'badgeId': badgeId,
        'earnedAt': earnedAt.millisecondsSinceEpoch,
        if (runId != null) 'runId': runId,
      };

  factory EarnedBadge.fromJson(Map<String, dynamic> json) => EarnedBadge(
        badgeId: json['badgeId'] as String,
        earnedAt: DateTime.fromMillisecondsSinceEpoch(
            (json['earnedAt'] as num).toInt()),
        runId: json['runId'] as String?,
      );
}

/// 전체 배지 16종
const List<BadgeDef> kBadges = [
  // 거리 (단일 세션)
  BadgeDef(
      id: 'first_run',
      title: '첫 발걸음',
      description: '첫 러닝 기록',
      category: BadgeCategory.distance),
  BadgeDef(
      id: 'first_5k',
      title: '5K 피니셔',
      description: '한 번에 5km 달리기',
      category: BadgeCategory.distance),
  BadgeDef(
      id: 'first_10k',
      title: '10K 러너',
      description: '한 번에 10km 달리기',
      category: BadgeCategory.distance),
  // 누적 거리
  BadgeDef(
      id: 'total_50k',
      title: '누적 50K',
      description: '누적 거리 50km',
      category: BadgeCategory.total),
  BadgeDef(
      id: 'total_100k',
      title: '누적 100K',
      description: '누적 거리 100km',
      category: BadgeCategory.total),
  BadgeDef(
      id: 'total_250k',
      title: '누적 250K',
      description: '누적 거리 250km',
      category: BadgeCategory.total),
  BadgeDef(
      id: 'total_500k',
      title: '누적 500K',
      description: '누적 거리 500km',
      category: BadgeCategory.total),
  // 시간
  BadgeDef(
      id: 'run_10min',
      title: '10분 주자',
      description: '10분 이상 달리기',
      category: BadgeCategory.time),
  BadgeDef(
      id: 'run_20min',
      title: '20분 주자',
      description: '20분 이상 달리기',
      category: BadgeCategory.time),
  BadgeDef(
      id: 'run_30min',
      title: '30분의 벽',
      description: '30분 이상 달리기',
      category: BadgeCategory.time),
  BadgeDef(
      id: 'run_60min',
      title: '1시간 러너',
      description: '60분 이상 달리기',
      category: BadgeCategory.time),
  // 꾸준함 (스트릭)
  BadgeDef(
      id: 'week_3runs',
      title: '주 3회 러너',
      description: '한 주에 3회 러닝',
      category: BadgeCategory.streak),
  BadgeDef(
      id: 'streak_2w',
      title: '2주 스트릭',
      description: '2주 연속 주 3회 러닝',
      category: BadgeCategory.streak),
  BadgeDef(
      id: 'streak_4w',
      title: '4주 스트릭',
      description: '4주 연속 주 3회 러닝',
      category: BadgeCategory.streak),
  BadgeDef(
      id: 'month_10runs',
      title: '월간 개근',
      description: '한 달에 10회 러닝',
      category: BadgeCategory.streak),
  // 스페셜
  BadgeDef(
      id: 'night_owl',
      title: '야간 러너',
      description: '21시 이후 러닝 10회',
      category: BadgeCategory.special),
];
