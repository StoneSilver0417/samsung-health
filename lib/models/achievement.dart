/// 업적(배지) 정의. Phase 1은 기본 5종 + 데모용 진행률 지원.
class BadgeDef {
  final String id;
  final String title;
  final String description;
  final String emoji;

  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.emoji,
  });
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

/// Phase 1 기본 업적 5종 (PRD 7. Phase 1)
const List<BadgeDef> kBadges = [
  BadgeDef(
    id: 'first_run',
    title: '첫 발걸음',
    description: '첫 러닝 기록',
    emoji: '🏃',
  ),
  BadgeDef(
    id: 'first_5k',
    title: '5K 피니셔',
    description: '한 번에 5km 달리기',
    emoji: '🏅',
  ),
  BadgeDef(
    id: 'week_3runs',
    title: '주 3회 러너',
    description: '한 주에 3회 러닝',
    emoji: '🔥',
  ),
  BadgeDef(
    id: 'run_30min',
    title: '30분의 벽',
    description: '30분 이상 달리기',
    emoji: '⏱️',
  ),
  BadgeDef(
    id: 'total_50k',
    title: '누적 50K',
    description: '누적 거리 50km 달성',
    emoji: '🛣️',
  ),
];
