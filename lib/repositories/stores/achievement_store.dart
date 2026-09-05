import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/achievement.dart';

/// 업적/배지(earnedBadges) 영속화 전담 Store
abstract class AchievementStore {
  List<EarnedBadge> getEarnedBadges();
  Future<void> saveEarnedBadges(List<EarnedBadge> badges);
  Future<void> clear();
}

/// Hive 기반 AchievementStore 구현체
class HiveAchievementStore implements AchievementStore {
  final Box<String> _badges;

  HiveAchievementStore(this._badges);

  @override
  List<EarnedBadge> getEarnedBadges() => _badges.values
      .map((raw) =>
          EarnedBadge.fromJson(jsonDecode(raw) as Map<String, dynamic>))
      .toList();

  @override
  Future<void> saveEarnedBadges(List<EarnedBadge> badges) async {
    for (final b in badges) {
      await _badges.put(b.badgeId, jsonEncode(b.toJson()));
    }
  }

  @override
  Future<void> clear() => _badges.clear();
}
