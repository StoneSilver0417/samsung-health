import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'run_detail_screen.dart';
import 'theme.dart';
import 'widgets/run_card.dart';

class RunsScreen extends ConsumerWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runsAsync = ref.watch(runsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('기록')),
      body: runsAsync.when(
        data: (runs) => runs.isEmpty
            ? const Center(
                child: Text('기록이 없습니다', style: kMetricLabelStyle))
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 24),
                itemCount: runs.length,
                itemBuilder: (context, i) => RunCard(
                  run: runs[i],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => RunDetailScreen(runId: runs[i].id)),
                  ),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('오류: $e', style: kMetricLabelStyle)),
      ),
    );
  }
}
