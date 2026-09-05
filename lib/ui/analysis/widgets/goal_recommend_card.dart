import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../logic/stats.dart';
import '../../../models/run_session.dart';
import '../../../providers.dart';
import '../../../services/gemini_service.dart';
import '../../settings_screen.dart';
import '../../theme.dart';

/// 누적·월간 기록을 바탕으로 다음 1~2주 목표를 생성하고 기기 로컬에 캐시한다.
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
  DateTime? _recommendedAt;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repoProvider);
    _recommendation = repo.getGoalRecommendation();
    _recommendedAt = repo.getGoalRecommendedAt();
  }

  Future<void> _generate() async {
    final repo = ref.read(repoProvider);
    final apiKey = repo.getGeminiApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('설정에서 Gemini API 키를 먼저 입력하세요'),
          action: SnackBarAction(
            label: '설정으로',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
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
        _recommendedAt = generatedAt;
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
    return Card(
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome,
                  size: AppIconSizes.sm,
                  color: AppColors.neon,
                ),
                AppSpacing.gapW6,
                const Text(
                  '다음 목표',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                    width: AppIconSizes.sm,
                    height: AppIconSizes.sm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton(
                    onPressed: _generate,
                    child: Text(_recommendation == null ? '생성' : '다시 생성'),
                  ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontSize: 12,
                  ),
                ),
              )
            else if (_recommendation != null) ...[
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s10),
                child: Text(
                  _recommendation!,
                  style: AppTypography.bodyMedium,
                ),
              ),
              if (_recommendedAt != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.s8),
                  child: Text(
                    '${DateFormat('M/d HH:mm').format(_recommendedAt!)} 생성',
                    style: AppTypography.metricLabel,
                  ),
                ),
            ] else if (!_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.s6),
                child: Text(
                  '버튼을 눌러 다음 1~2주 러닝 목표를 추천받아보세요',
                  style: AppTypography.metricLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
