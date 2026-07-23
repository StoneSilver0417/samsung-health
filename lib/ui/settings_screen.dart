import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import 'theme.dart';

/// AI 러닝 요약(Gemini API)용 API 키 입력. 기기 로컬(Hive)에만 저장되며
/// git 저장소에는 포함되지 않는다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _keyCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _keyCtrl = TextEditingController(
        text: ref.read(repoProvider).getGeminiApiKey() ?? '');
  }

  @override
  void dispose() {
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(repoProvider).setGeminiApiKey(_keyCtrl.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('저장했습니다')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('AI 러닝 요약 (Gemini API)',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Google AI Studio(aistudio.google.com)에서 무료로 발급받은 API 키를 입력하면\n'
            '러닝 상세 화면에서 AI가 기록을 요약·코멘트해줍니다. 키는 이 기기에만\n'
            '저장되며 외부로 전송되지 않습니다.',
            style: kMetricLabelStyle,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _keyCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Gemini API 키',
              hintText: 'AIza...',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.neon,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _save,
            child: const Text('저장',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
