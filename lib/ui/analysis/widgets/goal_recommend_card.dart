import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../../providers.dart';
import '../../../services/gemini_service.dart';
import '../../settings_screen.dart';
import '../../widgets/ai_report_presentation.dart';

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
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
                const Expanded(
                  child: Text('다음 목표 AI 제안', style: AppTypography.titleSmall),
                ),
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
            if (_loading) ...[
              const Row(
                children: [
                  SizedBox(
                    width: AppIconSizes.sm,
                    height: AppIconSizes.sm,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.neon,
                    ),
                  ),
                  AppSpacing.gapW12,
                  Expanded(
                    child: Text(
                      'AI가 다음 목표를 계산하는 중입니다...',
                      style: AppTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ] else if (_recommendation != null) ...[
              Text(
                extractAiReportSection(_recommendation!, '다음 1~2주 목표'),
                key: const Key('ai-goal-summary-text'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium,
              ),
              AppSpacing.gapH12,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const Key('ai-goal-full-report-button'),
                  onPressed: () => showAiReportSheet(
                    context,
                    title: 'AI 맞춤 다음 목표 가이드',
                    icon: Icons.flag,
                    report: _recommendation!,
                  ),
                  icon: const Icon(
                    Icons.article_outlined,
                    size: AppIconSizes.sm,
                  ),
                  label: const Text('상세 목표 보기'),
                ),
              ),
            ] else if (!hasKey) ...[
              const Text(
                'Gemini API 키를 설정하면 최근 기록을 바탕으로 다음 목표를 추천받을 수 있습니다.',
                style: AppTypography.bodySmall,
              ),
              AppSpacing.gapH8,
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.key, size: AppIconSizes.sm),
                label: const Text('API 키 설정하기'),
                style: TextButton.styleFrom(foregroundColor: AppColors.neon),
              ),
            ] else ...[
              const Text('아직 추천된 목표가 없습니다.', style: AppTypography.bodySmall),
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
