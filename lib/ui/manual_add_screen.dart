import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// Health Connect 동기화 장애 등으로 유실된 기록을 수동으로 채워 넣기 위한 화면.
/// 삼성헬스 앱에 남아있는 원본 값(날짜/거리/시간)을 사용자가 직접 입력한다.
class ManualAddScreen extends ConsumerStatefulWidget {
  const ManualAddScreen({super.key});

  @override
  ConsumerState<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends ConsumerState<ManualAddScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();
  final _kmCtrl = TextEditingController();
  final _hourCtrl = TextEditingController(text: '0');
  final _minCtrl = TextEditingController();
  final _secCtrl = TextEditingController(text: '0');
  final _hrCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _kmCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    _hrCtrl.dispose();
    _calCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final km = double.parse(_kmCtrl.text);
    final durationSec = (int.tryParse(_hourCtrl.text) ?? 0) * 3600 +
        (int.tryParse(_minCtrl.text) ?? 0) * 60 +
        (int.tryParse(_secCtrl.text) ?? 0);

    final start = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final end = start.add(Duration(seconds: durationSec));
    final avgHr = double.tryParse(_hrCtrl.text);
    final calories = double.tryParse(_calCtrl.text);

    final run = RunSession(
      id: 'manual-${start.millisecondsSinceEpoch}',
      startTime: start,
      endTime: end,
      distanceM: km * 1000,
      durationSec: durationSec,
      avgHr: avgHr,
      calories: calories,
      sourceName: 'manual',
    );

    setState(() => _saving = true);
    final result =
        await ref.read(runsProvider.notifier).importRuns([run]);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('기록을 추가했습니다')));
    for (final badge in result.newBadges) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('새 업적: ${badge.title} — ${badge.description}'),
        backgroundColor: AppColors.neonDim,
        duration: const Duration(seconds: 4),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('기록 수동 추가')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Health Connect 동기화 장애 등으로 누락된 기록을 삼성헬스 원본 값을 보고\n'
              '직접 입력할 때 사용하세요. 스플릿·심박 그래프 없이 요약 정보만 저장됩니다.',
              style: kMetricLabelStyle,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickDate,
                    child: Text(DateFormat('yyyy.M.d (E)', 'ko').format(_date)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickTime,
                    child: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _kmCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: '거리 (km)', hintText: '예: 5.2'),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || n <= 0) return '거리를 입력하세요';
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('소요 시간', style: kMetricLabelStyle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _hourCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '시간'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '분'),
                    validator: (v) {
                      final h = int.tryParse(_hourCtrl.text) ?? 0;
                      final m = int.tryParse(v ?? '');
                      final s = int.tryParse(_secCtrl.text) ?? 0;
                      if (h == 0 && (m == null || m == 0) && s == 0) {
                        return '시간을 입력하세요';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _secCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '초'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '평균 심박수 (선택)', hintText: '예: 152'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _calCtrl,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: '칼로리 (선택)', hintText: '예: 320'),
            ),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.neon,
                foregroundColor: Colors.black,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving ? null : _save,
              child: const Text('추가하기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
