import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/run_session.dart';
import '../../../providers.dart';
import '../../../services/gemini_service.dart';
import '../../settings_screen.dart';
import '../../theme.dart';

/// Gemini API로 러닝 1회를 요약·코칭. 결과는 기기 로컬에 캐시되어 재호출을 피한다.
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
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('설정에서 Gemini API 키를 먼저 입력하세요'),
        action: SnackBarAction(
          label: '설정으로',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ));
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
                  'AI 러닝 요약',
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
                    child: Text(_summary == null ? '생성' : '다시 생성'),
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
            else if (_summary != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.s10),
                child: Text(
                  _summary!,
                  style: AppTypography.bodyMedium,
                ),
              )
            else if (!_loading)
              const Padding(
                padding: EdgeInsets.only(top: AppSpacing.s6),
                child: Text(
                  '버튼을 눌러 이 러닝에 대한 AI 코멘트를 받아보세요',
                  style: AppTypography.metricLabel,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
