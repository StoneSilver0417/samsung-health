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
  String? _appVersion;
  final _updateService = UpdateService();

  @override
  void initState() {
    super.initState();
    // 홈 진입 시 조용히 새 버전 확인 (없거나 실패해도 아무 알림 없음)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadVersion();
      _checkForUpdate(silent: true);
    });
  }

  Future<void> _loadVersion() async {
    final version = await _updateService.currentVersion();
    if (!mounted) return;
    setState(() => _appVersion = version);
  }

  Future<void> _sync() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final result = await ref.read(runsProvider.notifier).sync();
      if (!mounted) return;
      _showResult(result);
    } catch (e) {
      if (!mounted) return;
      _showResult(SyncResult(error: '동기화 실패: $e'));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _checkForUpdate({bool silent = false}) async {
    late final String current;
    late final UpdateInfo? latest;
    try {
      current = await _updateService.currentVersion();
      latest = await _updateService.checkLatest();
    } catch (e) {
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('업데이트 확인 실패: $e')),
        );
      }
      return;
    }
    if (!mounted) return;
    final update = latest;
    if (update == null || !UpdateService.isNewer(current, update.version)) {
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
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br20,
        ),
        title: Text('새 버전 v${update.version}', style: AppTypography.titleLarge),
        content: Text(
          update.notes.trim().isEmpty
              ? '새 버전이 있습니다. 지금 업데이트할까요?'
              : update.notes,
          style: AppTypography.metricLabel,
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
              _downloadAndInstall(update);
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
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadius.br20,
        ),
        title: const Text('다운로드 중', style: AppTypography.titleLarge),
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
              AppSpacing.gapH12,
              Text(
                '${(v * 100).toStringAsFixed(0)}%',
                style: AppTypography.metricLabel,
              ),
            ],
          ),
        ),
      ),
    );
    var dialogDismissed = false;
    var downloadCompleted = false;
    try {
      final path = await _updateService.downloadApk(
          info, (p) => progress.value = p);
      downloadCompleted = true;
      if (!mounted) return;
      Navigator.pop(context);
      dialogDismissed = true;
      await _updateService.install(path);
    } catch (e) {
      if (!mounted) return;
      if (!dialogDismissed) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('업데이트 ${downloadCompleted ? '설치' : '다운로드'} 실패: $e'),
        ),
      );
    } finally {
      progress.dispose();
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
        title: Row(
          children: [
            const Text('RunLog'),
            AppSpacing.gapW8,
            if (_appVersion != null)
              Text(
                'v$_appVersion',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        actions: [
          if (_syncing)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.s14),
              child: SizedBox(
                width: AppIconSizes.standard,
                height: AppIconSizes.standard,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.sync,
                color: AppColors.neon,
                size: AppIconSizes.lg,
              ),
              tooltip: 'Health Connect 동기화',
              onPressed: _sync,
            ),
          PopupMenuButton<String>(
            tooltip: '더보기 메뉴',
            icon: const Icon(Icons.more_vert, size: AppIconSizes.lg),
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
            AppSpacing.gapH12,
            Center(
              child: WeeklyRing(
                weekKm: stats.weekKm,
                weekRuns: stats.weekRuns,
              ),
            ),
            AppSpacing.gapH8,
            Center(
              child: Text(
                lastSync == null
                    ? '동기화 전 — 위로 당기거나 ↻ 를 눌러 가져오기'
                    : '마지막 동기화 ${DateFormat('M/d HH:mm').format(lastSync)}',
                style: AppTypography.metricLabel,
              ),
            ),
            AppSpacing.gapH8,
            LevelCard(totalKm: stats.totalKm),
            _summaryRow(stats),
            const Padding(
              padding: AppSpacing.sectionHeaderTopPadding,
              child: Text(
                '최근 러닝',
                style: AppTypography.titleMedium,
              ),
            ),
            ...runsAsync.when(
              data: (runs) => runs.isEmpty
                  ? [
                      Padding(
                        padding: AppSpacing.all32,
                        child: Column(
                          children: [
                            const Text(
                              '아직 기록이 없어요.\n동기화하거나 이전 기록을 가져와보세요!',
                              textAlign: TextAlign.center,
                              style: AppTypography.metricLabel,
                            ),
                            AppSpacing.gapH16,
                            OutlinedButton.icon(
                              icon: const Icon(
                                Icons.history,
                                color: AppColors.neon,
                                size: AppIconSizes.md,
                              ),
                              label: const Text(
                                '이전 기록 가져오기',
                                style: TextStyle(color: AppColors.neon),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ImportScreen(),
                                ),
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
                                builder: (_) => RunDetailScreen(runId: r.id),
                              ),
                            ),
                          ))
                      .toList(),
              loading: () => const [
                Center(
                  child: Padding(
                    padding: AppSpacing.all32,
                    child: CircularProgressIndicator(),
                  ),
                )
              ],
              error: (e, _) => [
                Padding(
                  padding: AppSpacing.all32,
                  child: Text('오류: $e', style: AppTypography.metricLabel),
                )
              ],
            ),
            AppSpacing.gapH24,
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(StatsSummary stats) {
    Widget cell(String value, String label, String semantic) => Expanded(
          child: Semantics(
            label: semantic,
            child: Column(
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: AppTypography.metricLabel),
              ],
            ),
          ),
        );

    return Card(
      color: AppColors.cardElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s14),
        child: Row(
          children: [
            cell(
              '${stats.totalKm.toStringAsFixed(1)} km',
              '누적 거리',
              '누적 거리: ${stats.totalKm.toStringAsFixed(1)}킬로미터',
            ),
            cell(
              '${stats.totalRuns}회',
              '총 러닝',
              '총 러닝: ${stats.totalRuns}회',
            ),
            cell(
              '${stats.currentStreakWeeks}주',
              '주3회 스트릭',
              '주3회 스트릭: ${stats.currentStreakWeeks}주 연속 달성',
            ),
          ],
        ),
      ),
    );
  }
}
