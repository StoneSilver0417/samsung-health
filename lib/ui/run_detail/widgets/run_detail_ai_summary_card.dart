import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_design_tokens.dart';
import '../../../models/run_session.dart';
import '../../../providers.dart';
import '../../../services/gemini_service.dart';
import '../../settings_screen.dart';

class RunDetailAiSummaryCard extends ConsumerStatefulWidget {
  final RunSession run;
  final List<RunSession> recentRuns;

  const RunDetailAiSummaryCard({
    super.key,
    required this.run,
    required this.recentRuns,
  });

  @override
  ConsumerState<RunDetailAiSummaryCard> createState() =>
      _RunDetailAiSummaryCardState();
}

class _RunDetailAiSummaryCardState
    extends ConsumerState<RunDetailAiSummaryCard> {
  final _service = GeminiService();
  String? _summary;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _summary = ref.read(repoProvider).getAiSummary(widget.run.id);
  }

  Future<void> _generate() async {
    final apiKey = ref.read(repoProvider).getGeminiApiKey();
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
      final text =
          await _service.summarizeRun(apiKey, widget.run, widget.recentRuns);
      await ref.read(repoProvider).saveAiSummary(widget.run.id, text);
      if (!mounted) return;
      setState(() => _summary = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showFullReportModal(BuildContext context, String text) {
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
          initialChildSize: 0.7,
          maxChildSize: 0.9,
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
                      const Icon(Icons.auto_awesome,
                          color: AppColors.neon, size: 22),
                      AppSpacing.gapW8,
                      const Text(
                        'AI 러닝 상세 분석 보고서',
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
                  Icons.auto_awesome,
                  color: AppColors.neon,
                  size: AppIconSizes.standard,
                ),
                AppSpacing.gapW8,
                const Text(
                  'AI 코치 분석 요약',
                  style: AppTypography.titleSmall,
                ),
                const Spacer(),
                if (_summary != null && !_loading)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: AppIconSizes.sm),
                    color: AppColors.textSecondary,
                    tooltip: 'AI 요약 다시 생성',
                    onPressed: _generate,
                  ),
              ],
            ),
            AppSpacing.gapH12,
            if (!hasKey) ...[
              const Text(
                'Gemini API 키를 설정하면 러닝 세션별 AI 코칭 분석을 받아볼 수 있습니다.',
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
                    'AI 분석 보고서를 생성하는 중입니다...',
                    style: AppTypography.bodySmall,
                  ),
                ],
              ),
            ] else if (_summary != null) ...[
              Text(
                _summary!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium,
              ),
              AppSpacing.gapH12,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _showFullReportModal(context, _summary!),
                  icon: const Icon(Icons.open_in_new, size: AppIconSizes.sm),
                  label: const Text('전체 보고서 팝업으로 보기'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.neon,
                    side: const BorderSide(color: AppColors.borderFocused),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.br8,
                    ),
                  ),
                ),
              ),
            ] else ...[
              const Text(
                '아직 생성된 AI 분석 보고서가 없습니다.',
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
                label: const Text('AI 요약 리포트 생성'),
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
