import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../logic/stats.dart';
import '../models/run_session.dart';
import '../providers.dart';
import 'theme.dart';

enum _ManualInputMode { duration, pace }

/// Health Connect 동기화 장애 등으로 유실된 기록을 수동으로 채워 넣기 위한 화면.
/// 삼성헬스 앱에 남아있는 원본 값(날짜/거리/시간)을 사용자가 직접 입력한다.
class ManualAddScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final RunSession? editing;

  const ManualAddScreen({super.key, this.initialDate, this.editing});

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
  late final TextEditingController _paceMinCtrl;
  late final TextEditingController _paceSecCtrl;
  late final TextEditingController _hrCtrl;
  late final TextEditingController _maxHrCtrl;
  late final TextEditingController _calCtrl;
  _ManualInputMode _inputMode = _ManualInputMode.duration;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  double? get _distanceKm {
    final km = double.tryParse(_kmCtrl.text);
    if (km == null || !km.isFinite || km <= 0) return null;
    return km;
  }

  int? get _durationInputSec {
    final hour = _parseTimePart(_hourCtrl.text);
    final minute = _parseTimePart(_minCtrl.text, max59: true);
    final second = _parseTimePart(_secCtrl.text, max59: true);
    if (hour == null || minute == null || second == null) return null;
    final durationSec = hour * 3600 + minute * 60 + second;
    return durationSec > 0 ? durationSec : null;
  }

  int? get _paceInputSecPerKm {
    final minute = _parseTimePart(_paceMinCtrl.text);
    final second = _parseTimePart(_paceSecCtrl.text, max59: true);
    if (minute == null || second == null) return null;
    final paceSecPerKm = minute * 60 + second;
    return paceSecPerKm > 0 ? paceSecPerKm : null;
  }

  /// 소요시간 모드의 평균 페이스는 거리와 시간에서 정해지는 파생값이므로
  /// RunSession과 같은 공식으로 읽기 전용 미리보기만 계산한다.
  int? get _previewPaceSecPerKm {
    final km = _distanceKm;
    final durationSec = _durationInputSec;
    if (km == null || durationSec == null) return null;
    return (durationSec / km).round();
  }

  int? get _previewDurationSec {
    final km = _distanceKm;
    final paceSecPerKm = _paceInputSecPerKm;
    if (km == null || paceSecPerKm == null) return null;
    final durationSec = (km * paceSecPerKm).round();
    return durationSec > 0 ? durationSec : null;
  }

  int? get _resolvedDurationSec => _inputMode == _ManualInputMode.duration
      ? _durationInputSec
      : _previewDurationSec;

  static int? _parseTimePart(String text, {bool max59 = false}) {
    final normalized = text.trim();
    if (normalized.isEmpty) return 0;
    final value = int.tryParse(normalized);
    if (value == null || value < 0 || (max59 && value > 59)) return null;
    return value;
  }

  static String? _validateTimePart(String? value, {bool max59 = false}) {
    final normalized = (value ?? '').trim();
    if (normalized.isEmpty) return null;
    final number = int.tryParse(normalized);
    if (number == null || number < 0) return '0 이상의 정수를 입력하세요';
    if (max59 && number > 59) return '0~59로 입력하세요';
    return null;
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
    _paceMinCtrl = TextEditingController();
    _paceSecCtrl = TextEditingController(text: '0');
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
    _paceMinCtrl.dispose();
    _paceSecCtrl.dispose();
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

  void _changeInputMode(_ManualInputMode mode) {
    if (mode == _inputMode) return;

    // 거리·소요시간·페이스를 모두 자유 입력하면 값이 어긋날 수 있어,
    // 거리와 선택한 한 값만 원본으로 사용하는 두 입력 모드로 나눈다.
    if (mode == _ManualInputMode.pace) {
      final paceSecPerKm = _previewPaceSecPerKm;
      if (paceSecPerKm != null) {
        _paceMinCtrl.text = '${paceSecPerKm ~/ 60}';
        _paceSecCtrl.text = '${paceSecPerKm % 60}';
      } else {
        _paceMinCtrl.clear();
        _paceSecCtrl.text = '0';
      }
    } else {
      final durationSec = _previewDurationSec;
      if (durationSec != null) {
        _hourCtrl.text = '${durationSec ~/ 3600}';
        _minCtrl.text = '${(durationSec % 3600) ~/ 60}';
        _secCtrl.text = '${durationSec % 60}';
      } else {
        _hourCtrl.text = '0';
        _minCtrl.clear();
        _secCtrl.text = '0';
      }
    }

    setState(() => _inputMode = mode);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final km = double.parse(_kmCtrl.text);
    final durationSec = _resolvedDurationSec;
    if (durationSec == null) return;

    final start = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
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
    final result = await ref.read(runsProvider.notifier).importRuns([run]);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_isEditing ? '기록을 수정했습니다' : '기록을 추가했습니다')),
    );
    for (final badge in result.newBadges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('새 업적: ${badge.title} — ${badge.description}'),
          backgroundColor: AppColors.neonDim,
          duration: const Duration(seconds: 4),
        ),
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final previewPace = _previewPaceSecPerKm;
    final previewDuration = _previewDurationSec;

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
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '거리 (km)',
                hintText: '예: 5.2',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                if (n == null || !n.isFinite || n <= 0) {
                  return '거리를 입력하세요';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            const Text('입력 방식', style: kMetricLabelStyle),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('소요시간으로 입력'),
                  selected: _inputMode == _ManualInputMode.duration,
                  selectedColor: AppColors.neon.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.neon,
                  onSelected: (selected) {
                    if (selected) {
                      _changeInputMode(_ManualInputMode.duration);
                    }
                  },
                ),
                ChoiceChip(
                  label: const Text('페이스로 입력'),
                  selected: _inputMode == _ManualInputMode.pace,
                  selectedColor: AppColors.neon.withValues(alpha: 0.25),
                  checkmarkColor: AppColors.neon,
                  onSelected: (selected) {
                    if (selected) {
                      _changeInputMode(_ManualInputMode.pace);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: ValueKey(_inputMode),
              child: _inputMode == _ManualInputMode.duration
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('소요 시간', style: kMetricLabelStyle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _hourCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '시간',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) => _validateTimePart(v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '분',
                                  errorMaxLines: 2,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final error = _validateTimePart(
                                    v,
                                    max59: true,
                                  );
                                  if (error != null) return error;
                                  final allPartsValid =
                                      _parseTimePart(_hourCtrl.text) != null &&
                                      _parseTimePart(
                                            _minCtrl.text,
                                            max59: true,
                                          ) !=
                                          null &&
                                      _parseTimePart(
                                            _secCtrl.text,
                                            max59: true,
                                          ) !=
                                          null;
                                  if (allPartsValid &&
                                      _durationInputSec == null) {
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
                                decoration: const InputDecoration(
                                  labelText: '초',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) =>
                                    _validateTimePart(v, max59: true),
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
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('평균 페이스 (분/km)', style: kMetricLabelStyle),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _paceMinCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '분',
                                  errorMaxLines: 2,
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) {
                                  final error = _validateTimePart(v);
                                  if (error != null) return error;
                                  final allPartsValid =
                                      _parseTimePart(_paceMinCtrl.text) !=
                                          null &&
                                      _parseTimePart(
                                            _paceSecCtrl.text,
                                            max59: true,
                                          ) !=
                                          null;
                                  if (allPartsValid &&
                                      _paceInputSecPerKm == null) {
                                    return '0보다 크게 입력하세요';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _paceSecCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: '초',
                                ),
                                onChanged: (_) => setState(() {}),
                                validator: (v) =>
                                    _validateTimePart(v, max59: true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          previewDuration == null
                              ? '소요 시간: 거리와 페이스를 입력하세요'
                              : '소요 시간: ${fmtDuration(previewDuration)}',
                          style: TextStyle(
                            color: previewDuration == null
                                ? AppColors.textSecondary
                                : AppColors.neon,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _hrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '평균 심박수 (선택)',
                hintText: '예: 152',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _maxHrCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '최고 심박수 (선택)',
                hintText: '예: 178',
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '칼로리 (선택)',
                hintText: '예: 320',
              ),
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
