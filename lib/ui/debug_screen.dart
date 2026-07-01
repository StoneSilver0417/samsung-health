import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'theme.dart';

/// 동기화 누락 진단용 임시 화면. 최근 14일치 운동 기록을 두 경로로 대조한다.
/// 1) health 패키지 경유 (WORKOUT, 필터 없음)
/// 2) 네이티브 Health Connect SDK 직접 호출 (health 패키지 우회)
/// 한쪽에만 나오는 기록이 있으면 어느 쪽 문제인지 바로 구분된다.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  List<Map<String, String>>? _viaPackage;
  List<Map<String, String>>? _viaNative;
  List<Map<String, String>>? _viaPlanned;
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
      await health.requestExtraPermissions();
      final since = DateTime.now().subtract(const Duration(days: 14));
      final viaPackage = await health.debugRawWorkouts(since);
      final viaNative = await health.debugNativeSessions(since);
      final viaPlanned = await health.debugPlannedSessions(since);
      setState(() {
        _viaPackage = viaPackage;
        _viaNative = viaNative;
        _viaPlanned = viaPlanned;
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
      appBar: AppBar(title: const Text('진단: 운동 데이터 대조 (최근 14일)')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!, style: kMetricLabelStyle),
                  ),
                )
              : ListView(
                  children: [
                    _section('1) health 패키지 경유', _viaPackage!,
                        (r) => '${r['type']}\n${r['start']} ~ ${r['end']}\n출처: ${r['source']}'),
                    const Divider(thickness: 4),
                    _section('2) 네이티브 HC 직접 호출', _viaNative!,
                        (r) => 'exerciseType=${r['exerciseType']}  title=${r['title']}\n'
                            '${r['start']} ~ ${r['end']}\n출처: ${r['dataOrigin']}'),
                    const Divider(thickness: 4),
                    _section('3) 계획된 운동(Training Plan)', _viaPlanned!,
                        (r) => 'title=${r['title']}  완료세션=${r['completionUuid']}\n'
                            '${r['start']} ~ ${r['end']}\n출처: ${r['dataOrigin']}'),
                  ],
                ),
    );
  }

  Widget _section(String label, List<Map<String, String>> rows,
      String Function(Map<String, String>) format) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text('$label (${rows.length}건)',
              style: const TextStyle(
                  color: AppColors.neon, fontWeight: FontWeight.w800)),
        ),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('기록 없음'),
          )
        else
          ...rows.map((r) => Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Text(format(r), style: kMetricLabelStyle),
              )),
      ],
    );
  }
}
