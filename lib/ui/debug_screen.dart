import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'theme.dart';

/// 동기화 누락 진단용 임시 화면. Health Connect 원본 WORKOUT 레코드를
/// 필터링 없이 그대로 보여준다 (workoutActivityType 확인 목적).
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  List<Map<String, String>>? _rows;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final health = ref.read(healthServiceProvider);
    try {
      await health.configure();
      await health.requestPermissions();
      final rows = await health
          .debugRawWorkouts(DateTime.now().subtract(const Duration(days: 14)));
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('진단: 원본 운동 데이터 (최근 14일)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: kMetricLabelStyle),
                  ),
                )
              : _rows!.isEmpty
                  ? const Center(child: Text('최근 14일 WORKOUT 레코드 없음'))
                  : ListView.separated(
                      itemCount: _rows!.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _rows![i];
                        return ListTile(
                          title: Text(r['type'] ?? '?',
                              style: const TextStyle(
                                  color: AppColors.neon,
                                  fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${r['start']} ~ ${r['end']}\n출처: ${r['source']}'),
                          isThreeLine: true,
                        );
                      },
                    ),
    );
  }
}
