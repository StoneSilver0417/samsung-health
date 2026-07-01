import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// 과거 러닝 기록 가져오기 — 기간을 고르고, 찾은 기록 중 원하는 것만 선택해 추가.
/// 30일 이전 데이터는 Health Connect 히스토리 권한을 추가로 요청한다.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  static const _ranges = [
    (label: '1개월', days: 30),
    (label: '3개월', days: 90),
    (label: '6개월', days: 180),
    (label: '1년', days: 365),
  ];

  int _selectedRange = 1; // 기본 3개월
  bool _loading = false;
  String? _error;
  List<RunSession>? _candidates;
  final Set<String> _checked = {};
  Set<String> _alreadyImported = {};

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
      _candidates = null;
    });
    try {
      final from = DateTime.now()
          .subtract(Duration(days: _ranges[_selectedRange].days));
      final runs =
          await ref.read(runsProvider.notifier).fetchCandidates(from);
      final existing = (ref.read(runsProvider).value ?? const <RunSession>[])
          .map((r) => r.id)
          .toSet();
      setState(() {
        _candidates = runs;
        _alreadyImported = existing;
        _checked
          ..clear()
          ..addAll(runs.map((r) => r.id).where((id) => !existing.contains(id)));
      });
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _import() async {
    final selected = _candidates!
        .where((r) => _checked.contains(r.id))
        .toList();
    if (selected.isEmpty) return;
    // 체크 해제한 기록은 이후 동기화에서도 영구 제외
    final excluded = _candidates!
        .where((r) =>
            !_checked.contains(r.id) && !_alreadyImported.contains(r.id))
        .map((r) => r.id);
    setState(() => _loading = true);
    final result = await ref
        .read(runsProvider.notifier)
        .importRuns(selected, excludedIds: excluded);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
        SnackBar(content: Text('${result.addedCount}개 기록을 가져왔습니다')));
    for (final badge in result.newBadges) {
      messenger.showSnackBar(SnackBar(
        content:
            Text('새 업적: ${badge.title} — ${badge.description}'),
        backgroundColor: AppColors.neonDim,
        duration: const Duration(seconds: 4),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('이전 기록 가져오기')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: List.generate(_ranges.length, (i) {
                      return ChoiceChip(
                        label: Text(_ranges[i].label),
                        selected: _selectedRange == i,
                        selectedColor:
                            AppColors.neon.withValues(alpha: 0.25),
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _selectedRange = i),
                      );
                    }),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: _loading ? null : _search,
                  child: const Text('검색',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '30일 이전 기록은 헬스 커넥트의 "과거 데이터" 권한 허용이 필요해요',
              style: kMetricLabelStyle,
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
      bottomNavigationBar: _candidates == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.neon,
                    foregroundColor: Colors.black,
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed:
                      _loading || _checked.isEmpty ? null : _import,
                  child: Text(
                    '선택한 ${_checked.length}개 가져오기',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _body() {
    if (_loading && _candidates == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center, style: kMetricLabelStyle),
        ),
      );
    }
    final candidates = _candidates;
    if (candidates == null) {
      return const Center(
        child: Text('기간을 선택하고 검색을 눌러주세요', style: kMetricLabelStyle),
      );
    }
    if (candidates.isEmpty) {
      return const Center(
        child: Text('해당 기간에 러닝 기록이 없습니다', style: kMetricLabelStyle),
      );
    }

    final selectable = candidates
        .where((r) => !_alreadyImported.contains(r.id))
        .map((r) => r.id)
        .toSet();

    return Column(
      children: [
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          activeColor: AppColors.neon,
          checkColor: Colors.black,
          title: Text('전체 선택 (${selectable.length}개)',
              style: const TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          value: selectable.isNotEmpty && _checked.containsAll(selectable),
          onChanged: (v) => setState(() {
            if (v == true) {
              _checked.addAll(selectable);
            } else {
              _checked.clear();
            }
          }),
        ),
        const Divider(height: 1, color: Colors.white12),
        Expanded(
          child: ListView.builder(
            itemCount: candidates.length,
            itemBuilder: (context, i) {
              final run = candidates[i];
              final imported = _alreadyImported.contains(run.id);
              return CheckboxListTile(
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: AppColors.neon,
                checkColor: Colors.black,
                value: imported || _checked.contains(run.id),
                onChanged: imported
                    ? null
                    : (v) => setState(() {
                          if (v == true) {
                            _checked.add(run.id);
                          } else {
                            _checked.remove(run.id);
                          }
                        }),
                title: Text(
                  DateFormat('yyyy년 M월 d일 (E) HH:mm', 'ko')
                      .format(run.startTime),
                  style: TextStyle(
                    color: imported
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: Text(
                  imported
                      ? '이미 추가된 기록'
                      : '${run.distanceKm.toStringAsFixed(2)} km · '
                          '${fmtDuration(run.durationSec)} · '
                          '${fmtPace(run.avgPaceSecPerKm)}'
                          '${run.avgHr != null ? ' · 심박 ${run.avgHr!.round()}' : ''}',
                  style: kMetricLabelStyle,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
