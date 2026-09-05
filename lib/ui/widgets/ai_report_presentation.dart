import 'package:flutter/material.dart';

import '../../core/theme/app_design_tokens.dart';

String extractAiReportSection(String report, String heading) {
  final lines = report.trim().split('\n');
  final headingToken = '[$heading]';
  final start = lines.indexWhere((line) => line.contains(headingToken));

  if (start >= 0) {
    final section = <String>[];
    for (final line in lines.skip(start + 1)) {
      final trimmed = line.trim();
      if (trimmed == '---' ||
          (trimmed.contains('[') &&
              trimmed.contains(']') &&
              !trimmed.contains(headingToken))) {
        break;
      }
      section.add(line);
    }
    final extracted = section.join('\n').trim();
    if (extracted.isNotEmpty) return extracted;
  }

  final fallback = <String>[];
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty && fallback.isNotEmpty) break;
    if (trimmed.isEmpty || trimmed == '---' || trimmed.contains('[')) continue;
    fallback.add(line);
    if (fallback.length == 2) break;
  }
  return fallback.join('\n').trim().isEmpty
      ? report.trim()
      : fallback.join('\n').trim();
}

Future<void> showAiReportSheet(
  BuildContext context, {
  required String title,
  required IconData icon,
  required String report,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cardElevated,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.bottomSheetTop),
    builder: (sheetContext) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Padding(
        padding: AppSpacing.bottomSheetPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: AppSpacing.s4,
                margin: const EdgeInsets.only(bottom: AppSpacing.s16),
                decoration: const BoxDecoration(
                  color: AppColors.textTertiary,
                  borderRadius: AppRadius.brFull,
                ),
              ),
            ),
            Row(
              children: [
                Icon(icon, color: AppColors.neon, size: AppIconSizes.lg),
                AppSpacing.gapW8,
                Expanded(child: Text(title, style: AppTypography.titleMedium)),
                IconButton(
                  tooltip: '닫기',
                  icon: const Icon(Icons.close, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(sheetContext),
                ),
              ],
            ),
            const Divider(
              color: AppColors.borderSubtle,
              height: AppSpacing.s24,
            ),
            Expanded(
              child: Semantics(
                label: '$title 전체 내용',
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    report,
                    key: const Key('ai-full-report-text'),
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
