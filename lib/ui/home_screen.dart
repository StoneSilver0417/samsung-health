import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../providers.dart';
import '../services/update_service.dart';
import 'debug_screen.dart';
import 'import_screen.dart';
import 'manual_add_screen.dart';
import 'run_detail_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';
import 'widgets/level_card.dart';
import 'widgets/run_card.dart';
import 'widgets/weekly_ring.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _syncing = false;
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // 홈 진입 시 조용히 새 버전 확인 (없거나 실패해도 아무 알림 없음)
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkForUpdate(silent: true));
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final result = await ref.read(runsProvider.notifier).sync();
    setState(() => _syncing = false);
    _showResult(result);
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    final current = await _updateService.currentVersion();
    final latest = await _updateService.checkLatest();
    if (!mounted) return;
    if (latest == null || !UpdateService.isNewer(current, latest.version)) {
      if (!silent) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('이미 최신 버전입니다')));
      }
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('새 버전 v${latest.version}'),
        content: Text(
          latest.notes.trim().isEmpty
              ? '새 버전이 있습니다. 지금 업데이트할까요?'
              : latest.notes,
          style: kMetricLabelStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neon,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _downloadAndInstall(latest);
            },
            child: const Text('업데이트'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall(UpdateInfo info) async {
    final progress = ValueNotifier<double>(0);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('다운로드 중'),
        content: ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (_, v, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(
                value: v > 0 ? v : null,
                color: AppColors.neon,
                backgroundColor: Colors.white12,
              ),
              const SizedBox(height: 12),
              Text('${(v * 100).toStringAsFixed(0)}%',
                  style: kMetricLabelStyle),
            ],
          ),
        ),
      ),
    );
    try {
      final path = await _updateService.downloadApk(
          info.apkUrl, (p) => progress.value = p);
      if (!mounted) return;
      Navigator.pop(context);
      await _updateService.install(path);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('업데이트 다운로드 실패: $e')));
    }
  }

  void _showResult(SyncResult result) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result.error != null) {
      messenger.showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    messenger.showSnackBar(
      SnackBar(content: Text('새 러닝 ${result.addedCount}개 동기화 완료')),
    );
    for (final badge in result.newBadges) {
      messenger.showSnackBar(SnackBar(
        content: Text('새 업적: ${badge.title} — ${badge.description}'),
        backgroundColor: AppColors.neonDim,
        duration: const Duration(seconds: 4),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(runsProvider);
    final stats = ref.watch(statsProvider);
    final lastSync = ref.read(repoProvider).lastSyncedAt;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('RunLog'),
            SizedBox(width: 8),
            Text('v1.6.1',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.sync, color: AppColors.neon),
              tooltip: 'Health Connect 동기화',
              onPressed: _sync,
            ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              final notifier = ref.read(runsProvider.notifier);
              if (v == 'import') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ImportScreen()),
                );
              } else if (v == 'manual') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManualAddScreen()),
                );
              } else if (v == 'demo') {
                _showResult(await notifier.seedDemoData());
              } else if (v == 'clear') {
                await notifier.clearAll();
              } else if (v == 'debug') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DebugScreen()),
                );
              } else if (v == 'update') {
                await _checkForUpdate();
              } else if (v == 'settings') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('이전 기록 가져오기')),
              PopupMenuItem(value: 'manual', child: Text('기록 수동 추가')),
              PopupMenuItem(value: 'update', child: Text('업데이트 확인')),
              PopupMenuItem(value: 'settings', child: Text('설정 (AI 요약 등)')),
              PopupMenuItem(value: 'demo', child: Text('데모 데이터 넣기')),
              PopupMenuItem(value: 'clear', child: Text('데이터 전체 삭제')),
              PopupMenuItem(value: 'debug', child: Text('진단: 원본 운동 데이터')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.neon,
        onRefresh: _sync,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 12),
            Center(
              child: WeeklyRing(
                weekKm: stats.weekKm,
                weekRuns: stats.weekRuns,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                lastSync == null
                    ? '동기화 전 — 위로 당기거나 ↻ 를 눌러 가져오기'
                    : '마지막 동기화 ${DateFormat('M/d HH:mm').format(lastSync)}',
                style: kMetricLabelStyle,
              ),
            ),
            const SizedBox(height: 8),
            LevelCard(totalKm: stats.totalKm),
            _summaryRow(stats),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Text('최근 러닝',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ),
            ...runsAsync.when(
              data: (runs) => runs.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Text(
                                '아직 기록이 없어요.\n동기화하거나 이전 기록을 가져와보세요!',
                                textAlign: TextAlign.center,
                                style: kMetricLabelStyle),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.history,
                                  color: AppColors.neon),
                              label: const Text('이전 기록 가져오기',
                                  style:
                                      TextStyle(color: AppColors.neon)),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const ImportScreen()),
                              ),
                            ),
                          ],
                        ),
                      )
                    ]
                  : runs
                      .take(3)
                      .map((r) => RunCard(
                            run: r,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => RunDetailScreen(runId: r.id)),
                            ),
                          ))
                      .toList(),
              loading: () => const [
                Center(child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator()))
              ],
              error: (e, _) => [
                Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text('오류: $e', style: kMetricLabelStyle))
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(StatsSummary stats) {
    Widget cell(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              Text(label, style: kMetricLabelStyle),
            ],
          ),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            cell('${stats.totalKm.toStringAsFixed(1)} km', '누적 거리'),
            cell('${stats.totalRuns}회', '총 러닝'),
            cell('${stats.currentStreakWeeks}주', '주3회 스트릭'),
          ],
        ),
      ),
    );
  }
}
