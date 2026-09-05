import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/run_session.dart';
import '../providers.dart';
import 'manual_add_screen.dart';
import 'run_detail/widgets/run_detail_ai_summary_card.dart';
import 'run_detail/widgets/run_detail_delete_dialog.dart';
import 'run_detail/widgets/run_detail_hero_header.dart';
import 'run_detail/widgets/run_detail_hr_chart_card.dart';
import 'run_detail/widgets/run_detail_laps_table_card.dart';
import 'run_detail/widgets/run_detail_running_dynamics_card.dart';
import 'theme.dart';

/// 러닝 세션 상세 화면 (지표, AI 분석, 심박, 랩, 인터벌 등)
class RunDetailScreen extends ConsumerWidget {
  final String runId;

  const RunDetailScreen({super.key, required this.runId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runs = ref.watch(runsProvider).value ?? const <RunSession>[];
    final run = _findRun(runs, runId);
    if (run == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(
          child: Text('기록을 찾을 수 없습니다', style: AppTypography.bodyMedium),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M월 d일 (E)', 'ko').format(run.startTime)),
        actions: [
          if (run.sourceName == 'manual')
            IconButton(
              tooltip: '기록 수정',
              icon: const Icon(
                Icons.edit_outlined,
                color: AppColors.neon,
                size: AppIconSizes.lg,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManualAddScreen(editing: run),
                  ),
                );
              },
            ),
          IconButton(
            tooltip: '기록 삭제',
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.danger,
              size: AppIconSizes.lg,
            ),
            onPressed: () async {
              final ok = await RunDetailDeleteDialog.show(context);
              if (ok == true && context.mounted) {
                await ref.read(runsProvider.notifier).deleteRun(runId);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.s32),
        children: [
          RunDetailHeroHeader(run: run),
          RunDetailAiSummaryCard(
            run: run,
            recentRuns: runs
                .where((r) => r.startTime.isBefore(run.startTime))
                .take(5)
                .toList(),
          ),
          if (run.hrSeries.length >= 2) ...[
            _sectionTitle('심박수'),
            RunDetailHrChartCard(run: run),
            _sectionTitle('심박존 분포'),
            RunDetailHrZonesCard(run: run),
          ],
          _sectionTitle('러닝 역학 & 심폐 효율'),
          RunDetailRunningDynamicsCard(run: run),
          if (run.laps.isNotEmpty) ...[
            _sectionTitle('워치 랩 기록'),
            RunDetailLapsTableCard(run: run),
          ],
          if (run.segments.isNotEmpty) ...[
            _sectionTitle('인터벌'),
            RunDetailSegmentsCard(run: run),
          ],
        ],
      ),
    );
  }

  static RunSession? _findRun(List<RunSession> runs, String id) {
    for (final run in runs) {
      if (run.id == id) return run;
    }
    return null;
  }

  Widget _sectionTitle(String t) => Padding(
        padding: AppSpacing.sectionHeaderPadding,
        child: Text(t, style: AppTypography.titleMedium),
      );
}
