import 'package:flutter/material.dart';

import '../../models/run_session.dart';
import '../theme.dart';

/// 월별 달력 형식의 러닝 기록 — 뛴 날은 거리에 따라 네온 강도로 표시.
/// 좌우 화살표로 월 이동, 날짜 탭 시 콜백.
class CalendarHeatmap extends StatefulWidget {
  final List<RunSession> runs;
  final void Function(List<RunSession> dayRuns)? onDayTap;

  const CalendarHeatmap({super.key, required this.runs, this.onDayTap});

  @override
  State<CalendarHeatmap> createState() => _CalendarHeatmapState();
}

class _CalendarHeatmapState extends State<CalendarHeatmap> {
  late DateTime _month; // 해당 월의 1일

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final dayMap = <DateTime, List<RunSession>>{};
    for (final r in widget.runs) {
      final d = DateTime(r.startTime.year, r.startTime.month, r.startTime.day);
      (dayMap[d] ??= []).add(r);
    }

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // 이 달 1일의 요일 (월=1 ... 일=7) → 앞 빈칸 수
    final firstWeekday = _month.weekday; // 1=월
    final leading = firstWeekday - 1;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    // 이번 달 러닝 요약
    var monthKm = 0.0;
    var monthRuns = 0;
    for (int d = 1; d <= daysInMonth; d++) {
      final rs = dayMap[DateTime(_month.year, _month.month, d)];
      if (rs != null) {
        monthRuns += rs.length;
        monthKm += rs.fold(0.0, (s, r) => s + r.distanceKm);
      }
    }

    final canGoNext = _month.isBefore(DateTime(today.year, today.month, 1));

    const weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left,
                  color: AppColors.textSecondary),
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1, 1)),
            ),
            Expanded(
              child: Column(
                children: [
                  Text('${_month.year}년 ${_month.month}월',
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  Text(
                    monthRuns == 0
                        ? '기록 없음'
                        : '$monthRuns회 · ${monthKm.toStringAsFixed(1)} km',
                    style: kMetricLabelStyle,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right,
                  color: canGoNext
                      ? AppColors.textSecondary
                      : Colors.white24),
              onPressed: canGoNext
                  ? () => setState(() =>
                      _month = DateTime(_month.year, _month.month + 1, 1))
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (i) {
            final isWeekend = i >= 5;
            return Expanded(
              child: Center(
                child: Text(
                  weekdayLabels[i],
                  style: TextStyle(
                    color: isWeekend
                        ? AppColors.danger.withValues(alpha: 0.8)
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        ...List.generate(rows, (row) {
          return Row(
            children: List.generate(7, (col) {
              final cellIndex = row * 7 + col;
              final dayNum = cellIndex - leading + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const Expanded(child: SizedBox(height: 44));
              }
              final date = DateTime(_month.year, _month.month, dayNum);
              final rs = dayMap[date];
              final km = rs?.fold(0.0, (s, r) => s + r.distanceKm) ?? 0.0;
              final isToday = date == todayDate;
              final hasRun = rs != null;

              return Expanded(
                child: GestureDetector(
                  onTap: hasRun && widget.onDayTap != null
                      ? () => widget.onDayTap!(rs)
                      : null,
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: hasRun ? _fillColor(km) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(color: AppColors.neon, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNum',
                          style: TextStyle(
                            color: hasRun
                                ? Colors.black
                                : (col >= 5
                                    ? AppColors.danger.withValues(alpha: 0.7)
                                    : AppColors.textPrimary),
                            fontSize: 13,
                            fontWeight:
                                hasRun ? FontWeight.w900 : FontWeight.w500,
                          ),
                        ),
                        if (hasRun)
                          Text(
                            km.toStringAsFixed(1),
                            style: const TextStyle(
                                color: Colors.black,
                                fontSize: 9,
                                fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          );
        }),
      ],
    );
  }

  static Color _fillColor(double km) {
    if (km < 3) return AppColors.neon.withValues(alpha: 0.45);
    if (km < 6) return AppColors.neon.withValues(alpha: 0.72);
    return AppColors.neon;
  }
}
