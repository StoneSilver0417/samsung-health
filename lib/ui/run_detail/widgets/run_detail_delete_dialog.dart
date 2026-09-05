import 'package:flutter/material.dart';

import '../../theme.dart';

/// 기록 삭제 확인 다이얼로그
class RunDetailDeleteDialog extends StatelessWidget {
  const RunDetailDeleteDialog({super.key});

  /// 삭제 확인 다이얼로그를 표시하고 사용자 선택 결과(true/false)를 반환
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => const RunDetailDeleteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: AppRadius.br20,
      ),
      title: const Text('기록 삭제', style: AppTypography.titleLarge),
      content: const Text(
        '이 러닝 기록을 삭제할까요?',
        style: AppTypography.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text(
            '삭제',
            style: TextStyle(
              color: AppColors.danger,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
