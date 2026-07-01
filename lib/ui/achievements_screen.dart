import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/achievement_engine.dart';
import '../models/achievement.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// 배지 보관함 (PRD 4.3) — 카테고리별 섹션, 획득은 컬러 / 미획득은 흑백 실루엣 + 진행률.
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
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          for (final category in BadgeCategory.values) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text(category.label,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              childAspectRatio: 0.72,
              children: kBadges
                  .where((b) => b.category == category)
                  .map((b) => _BadgeTile(
                        badge: b,
                        earned: earned[b.id],
                        progress: earned[b.id] == null
                            ? AchievementEngine.progressText(b.id, runs)
                            : null,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  final BadgeDef badge;
  final EarnedBadge? earned;
  final String? progress;

  const _BadgeTile({required this.badge, this.earned, this.progress});

  @override
  Widget build(BuildContext context) {
    final isEarned = earned != null;

    Widget image = ClipOval(
      child: Image.asset(
        badge.assetPath,
        fit: BoxFit.cover,
      ),
    );
    if (!isEarned) {
      image = Opacity(
        opacity: 0.35,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0.2126, 0.7152, 0.0722, 0, 0,
            0, 0, 0, 1, 0,
          ]),
          child: image,
        ),
      );
    }

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            Expanded(child: image),
            const SizedBox(height: 6),
            Text(
              badge.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isEarned
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              isEarned
                  ? DateFormat('yyyy.M.d').format(earned!.earnedAt)
                  : (progress ?? badge.description),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isEarned ? AppColors.neon : AppColors.textSecondary,
                fontSize: 10.5,
                fontWeight: isEarned ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.card,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              28, 16, 28, 28 + MediaQuery.viewPaddingOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            SizedBox(
              width: 170,
              height: 170,
              child: earned != null
                  ? ClipOval(child: Image.asset(badge.assetPath))
                  : Opacity(
                      opacity: 0.4,
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0.2126, 0.7152, 0.0722, 0, 0,
                          0, 0, 0, 1, 0,
                        ]),
                        child: ClipOval(child: Image.asset(badge.assetPath)),
                      ),
                    ),
            ),
            const SizedBox(height: 18),
            Text(badge.title,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(badge.description,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 10),
            if (earned != null)
              Text(
                '${DateFormat('yyyy년 M월 d일').format(earned!.earnedAt)} 획득',
                style: const TextStyle(
                    color: AppColors.neon,
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              )
            else if (progress != null)
              Text(progress!,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
