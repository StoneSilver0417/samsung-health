import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../../providers.dart';
import '../../../services/gemini_service.dart';
import '../../settings_screen.dart';

class GoalRecommendCard extends ConsumerStatefulWidget {
  final StatsSummary stats;
  final MonthlyStats monthly;
  final List<RunSession> recentRuns;

  const GoalRecommendCard({
    super.key,
    required this.stats,
    required this.monthly,
    required this.recentRuns,
  });

  @override
  ConsumerState<GoalRecommendCard> createState() => _GoalRecommendCardState();
}

class _GoalRecommendCardState extends ConsumerState<GoalRecommendCard> {
  final _service = GeminiService();
  String? _recommendation;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repoProvider);
    _recommendation = repo.getGoalRecommendation();
  }

  Future<void> _generate() async {
    final repo = ref.read(repoProvider);
    final apiKey = repo.getGeminiApiKey();

    if (apiKey == null || apiKey.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gemini API 키가 필요합니다.'),
          action: SnackBarAction(
            label: '설정',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final text = await _service.recommendGoal(
        apiKey,
        widget.stats,
        widget.monthly,
        widget.recentRuns,
      );
      final generatedAt = DateTime.now();
      await repo.saveGoalRecommendation(text, generatedAt);
      if (!mounted) return;
      setState(() {
        _recommendation = text;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFullGoalModal(BuildContext context, String text) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.bottomSheetTop,
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.85,
          minChildSize: 0.4,
          builder: (_, controller) {
            return Container(
              padding: AppSpacing.bottomSheetPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                      decoration: const BoxDecoration(
                        color: AppColors.textTertiary,
                        borderRadius: AppRadius.brFull,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.flag, color: AppColors.neon, size: 22),
                      AppSpacing.gapW8,
                      const Text(
                        'AI 맞춤 다음 목표 가이드',
                        style: AppTypography.titleMedium,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close,
                            color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: AppColors.borderSubtle, height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: controller,
                      child: Text(
                        text,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textPrimary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final apiKey = ref.watch(repoProvider).getGeminiApiKey();
    final hasKey = apiKey != null && apiKey.trim().isNotEmpty;

    return Container(
      margin: AppSpacing.cardMargin,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.br16,
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.flag,
                  color: AppColors.neon,
                  size: AppIconSizes.standard,
                ),
                AppSpacing.gapW8,
                const Text(
                  '다음 목표 AI 제안',
                  style: AppTypography.titleSmall,
                ),
                const Spacer(),
                if (hasKey && !_loading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: AppIconSizes.sm),
                    color: AppColors.textSecondary,
                    tooltip: '목표 다시 생성',
                    onPressed: _generate,
                  ),
              ],
            ),
            AppSpacing.gapH12,
            if (!hasKey) ...[
              const Text(
                'Gemini API 키를 설정하면 최근 기록을 바탕으로 다음 목표를 추천받을 수 있습니다.',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapH8,
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.key, size: AppIconSizes.sm),
                label: const Text('API 키 설정하기'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.neon,
                ),
              ),
            ] else if (_loading) ...[
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neon,
                    ),
                  ),
                  AppSpacing.gapW12,
                  Text(
                    'AI가 다음 목표를 계산하는 중입니다...',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ] else if (_recommendation != null) ...[
              Text(
                _recommendation!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium,
              ),
              AppSpacing.gapH12,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showFullGoalModal(
                    context,
                    _recommendation!,
                  ),
                  icon: const Icon(Icons.open_in_new, size: AppIconSizes.sm),
                  label: const Text('상세 목표 팝업으로 보기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neon,
                    side: const BorderSide(
                      color: AppColors.borderFocused,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.br8,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                '아직 추천된 목표가 없습니다.',
                style: AppTypography.bodySmall,
              ),
              if (_error != null) ...[
                AppSpacing.gapH8,
                Text(
                  _error!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              AppSpacing.gapH12,
              ElevatedButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome, size: AppIconSizes.sm),
                label: const Text('목표 추천받기'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.neon,
                  foregroundColor: AppColors.textOnNeon,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
