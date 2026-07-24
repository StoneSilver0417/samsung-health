import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

/// Health Connect 동기화 장애 등으로 유실된 기록을 수동으로 채워 넣기 위한 화면.
/// 삼성헬스 앱에 남아있는 원본 값(날짜/거리/시간)을 사용자가 직접 입력한다.
class ManualAddScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final RunSession? editing;

  const ManualAddScreen({
    super.key,
    this.initialDate,
    this.editing,
  });

  @override
  ConsumerState<ManualAddScreen> createState() => _ManualAddScreenState();
}

class _ManualAddScreenState extends ConsumerState<ManualAddScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date;
  late TimeOfDay _time;
  late final TextEditingController _kmCtrl;
  late final TextEditingController _hourCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _secCtrl;
  late final TextEditingController _hrCtrl;
  late final TextEditingController _maxHrCtrl;
  late final TextEditingController _calCtrl;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  int get _durationSec =>
      (int.tryParse(_hourCtrl.text) ?? 0) * 3600 +
      (int.tryParse(_minCtrl.text) ?? 0) * 60 +
      (int.tryParse(_secCtrl.text) ?? 0);

  /// 평균 페이스는 거리와 시간에서 정해지는 파생값이라 별도 입력·저장하면
  /// 원본 수치와 어긋날 수 있으므로 RunSession과 같은 공식으로 미리보기만 계산한다.
  int? get _previewPaceSecPerKm {
    final km = double.tryParse(_kmCtrl.text);
    final durationSec = _durationSec;
    if (km == null || km <= 0 || durationSec <= 0) return null;
    return (durationSec / km).round();
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final editing = widget.editing;
    final selected = editing?.startTime ?? widget.initialDate ?? now;
    _date = DateTime(selected.year, selected.month, selected.day);
    _time = editing == null
        ? TimeOfDay.fromDateTime(now)
        : TimeOfDay.fromDateTime(editing.startTime);

    final durationSec = editing?.durationSec ?? 0;
    _kmCtrl = TextEditingController(text: _numberText(editing?.distanceKm));
    _hourCtrl = TextEditingController(
      text: editing == null ? '0' : '${durationSec ~/ 3600}',
    );
    _minCtrl = TextEditingController(
      text: editing == null ? '' : '${(durationSec % 3600) ~/ 60}',
    );
    _secCtrl = TextEditingController(
      text: editing == null ? '0' : '${durationSec % 60}',
    );
    _hrCtrl = TextEditingController(text: _numberText(editing?.avgHr));
    _maxHrCtrl = TextEditingController(text: _numberText(editing?.maxHr));
    _calCtrl = TextEditingController(text: _numberText(editing?.calories));
  }

  static String _numberText(double? value) {
    if (value == null) return '';
    if (value == value.truncateToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _kmCtrl.dispose();
    _hourCtrl.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    _hrCtrl.dispose();
    _maxHrCtrl.dispose();
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
    final durationSec = _durationSec;

    final start = DateTime(
        _date.year, _date.month, _date.day, _time.hour, _time.minute);
    final end = start.add(Duration(seconds: durationSec));
    final avgHr = double.tryParse(_hrCtrl.text);
    final maxHr = double.tryParse(_maxHrCtrl.text);
    final calories = double.tryParse(_calCtrl.text);
    final editing = widget.editing;

    final run = RunSession(
      id: editing?.id ?? 'manual-${start.millisecondsSinceEpoch}',
      startTime: start,
      endTime: end,
      distanceM: km * 1000,
      durationSec: durationSec,
      avgHr: avgHr,
      maxHr: maxHr,
      calories: calories,
      steps: editing?.steps,
      elevationM: editing?.elevationM,
      splits: editing?.splits ?? const [],
      segments: editing?.segments ?? const [],
      hrSeries: editing?.hrSeries ?? const [],
      sourceName: 'manual',
    );

    setState(() => _saving = true);
    final result =
        await ref.read(runsProvider.notifier).importRuns([run]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? '기록을 수정했습니다' : '기록을 추가했습니다'),
      ),
    );
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
    final previewPace = _previewPaceSecPerKm;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '기록 수정' : '기록 수동 추가')),
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
              onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _minCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '분'),
                    onChanged: (_) => setState(() {}),
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
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              previewPace == null
                  ? '평균 페이스: 거리와 시간을 입력하세요'
                  : '평균 페이스: ${fmtPace(previewPace)}/km',
              style: TextStyle(
                color: previewPace == null
                    ? AppColors.textSecondary
                    : AppColors.neon,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
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
              controller: _maxHrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: '최고 심박수 (선택)', hintText: '예: 178'),
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
              child: Text(
                _isEditing ? '수정하기' : '추가하기',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
