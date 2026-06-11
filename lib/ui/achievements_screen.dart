import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/achievement_engine.dart';
import '../models/achievement.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// 배지 보관함 (PRD 4.3) — 획득 배지는 컬러, 미획득은 실루엣 + 진행률.
class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final earned = ref.watch(earnedBadgesProvider);
    final runs = ref.watch(runsProvider).value ?? const <RunSession>[];

    return Scaffold(
      appBar: AppBar(
        title: Text('업적  ${earned.length}/${kBadges.length}'),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemCount: kBadges.length,
        itemBuilder: (context, i) {
          final badge = kBadges[i];
          final earnedBadge = earned[badge.id];
          final isEarned = earnedBadge != null;
          final progress = isEarned
              ? null
              : AchievementEngine.progressText(badge.id, runs);

          return Container(
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: isEarned
                  ? Border.all(
                      color: AppColors.neon.withValues(alpha: 0.5), width: 1.5)
                  : null,
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Opacity(
                  opacity: isEarned ? 1 : 0.25,
                  child: Text(badge.emoji,
                      style: const TextStyle(fontSize: 44)),
                ),
                const SizedBox(height: 8),
                Text(
                  badge.title,
                  style: TextStyle(
                    color: isEarned
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  badge.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                ),
                const SizedBox(height: 6),
                if (isEarned)
                  Text(
                    DateFormat('yyyy.M.d').format(earnedBadge.earnedAt),
                    style: const TextStyle(
                        color: AppColors.neon,
                        fontSize: 11,
                        fontWeight: FontWeight.w700),
                  )
                else if (progress != null)
                  Text(progress,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}
