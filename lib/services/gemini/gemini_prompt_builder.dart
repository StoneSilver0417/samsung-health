import '../../logic/stats.dart';
import '../../models/run_session.dart';

/// Gemini AI 러닝 요약 및 목표 제안용 프롬프트 생성 빌더.
class GeminiPromptBuilder {
  const GeminiPromptBuilder._();

  /// 유효한 페이스를 가진 러닝 세션들의 평균 페이스(초/km)를 계산한다.
  static int? averagePaceSecPerKm(List<RunSession> runs) {
    final validPaces = runs
        .map((r) => r.avgPaceSecPerKm)
        .where((pace) => pace > 0)
        .toList();
    if (validPaces.isEmpty) return null;
    return (validPaces.reduce((a, b) => a + b) / validPaces.length).round();
  }

  /// 단일 러닝 세션에 대한 전문 코칭 피드백 프롬프트 생성.
  static String buildRunSummaryPrompt(
    RunSession run,
    List<RunSession> recentRuns,
  ) {
    final buf = StringBuffer();
    buf.writeln(
      '너는 전문 개인 러닝 코치야. 아래 러닝 기록 데이터를 심층 분석해서 한국어로 전문적이고 실용적인 코칭 피드백을 작성해줘.',
    );
    buf.writeln(
      '이모지나 과장된 감탄사 없이, 명확하고 논리적인 톤으로 아래 3가지 섹션 형식에 맞춰 작성해줘:',
    );
    buf.writeln();
    buf.writeln('📌 [핵심 요약]');
    buf.writeln('- 이번 러닝의 총평과 주요 성과 요약 (1~2문장)');
    buf.writeln();
    buf.writeln('📊 [페이스 & 심박 분석]');
    buf.writeln(
      '- 제공된 [구간별 스플릿] 또는 [워치 랩 기록] 데이터를 바탕으로 각 구간(km)별 페이스 변화(네거티브/포지티브/이븐 스플릿 등)를 반드시 구체적으로 분석해줘 (절대 페이스나 스플릿 정보를 모른다고 답하지 말고, 데이터가 없더라도 평단 페이스 추이를 기반으로 작성해라).',
    );
    buf.writeln(
      '- 심박수 및 심박존(유산소/지구력/역치) 분포를 바탕으로 한 심폐 효율 및 체력 부하 분석',
    );
    buf.writeln('- 최근 러닝 평균과의 비교 및 성장 포인트');
    buf.writeln();
    buf.writeln('💡 [맞춤 코칭 팁]');
    buf.writeln(
      '- 이번 러닝 데이터를 기반으로 한 다음 훈련 조언 (회복런, 심박존 관리, 케이던스/자세, 다음 목표 거리/페이스 제안 등 실천 가능한 구체적 팁 1~2개)',
    );
    buf.writeln();
    buf.writeln('---');
    buf.writeln('[이번 러닝 데이터]');
    buf.writeln('- 거리: ${run.distanceKm.toStringAsFixed(2)}km');
    buf.writeln('- 소요 시간: ${fmtDuration(run.durationSec)}');
    buf.writeln('- 평균 페이스: ${fmtPace(run.avgPaceSecPerKm)}/km');
    if (run.avgHr != null) buf.writeln('- 평균 심박수: ${run.avgHr!.round()}bpm');
    if (run.maxHr != null) buf.writeln('- 최고 심박수: ${run.maxHr!.round()}bpm');
    if (run.calories != null) {
      buf.writeln('- 소모 칼로리: ${run.calories!.round()}kcal');
    }
    if (run.steps != null && run.steps! > 0 && run.durationSec > 0) {
      final spm = (run.steps! / (run.durationSec / 60)).round();
      buf.writeln('- 총 걸음수: ${run.steps}걸음 (평균 케이던스: ${spm}spm)');
    }
    if (run.strideCm != null) {
      buf.writeln('- 평균 보폭: ${run.strideCm!.round()}cm');
    }
    if (run.cardiacDriftPct != null) {
      buf.writeln(
        '- 심박수 드리프트: ${run.cardiacDriftPct! >= 0 ? '+' : ''}${run.cardiacDriftPct!.toStringAsFixed(1)}% (${run.cardiacDriftPct! < 5.0 ? '지구력 안정적' : run.cardiacDriftPct! <= 10.0 ? '정상 피로' : '심폐 과부하/탈진 주의'})',
      );
    }
    final ratio = run.aerobicAnaerobicRatio;
    if (ratio != null) {
      buf.writeln(
        '- 유산소/무산소 비율: 유산소 ${ratio.aerobicPct.round()}% / 무산소 ${ratio.anaerobicPct.round()}%',
      );
    }
    buf.writeln(
      '- 훈련 부하(TRIMP): ${run.trainingLoadScore}pt (권장 회복 휴식: ${run.recommendedRecoveryHours}시간)',
    );
    if (run.elevationM != null && run.elevationM! > 0) {
      buf.writeln('- 획득 고도: ${run.elevationM!.toStringAsFixed(1)}m');
    }
    final hour = run.startTime.hour;
    buf.writeln(
      '- 러닝 시간대: ${run.startTime.hour}시 (${hour >= 21 || hour < 4 ? '야간' : hour < 8 ? '새벽' : '주간'} 러닝)',
    );

    // 워치 실제 랩 데이터 (있는 경우)
    if (run.laps.isNotEmpty) {
      buf.writeln();
      buf.writeln('[워치 랩 기록]');
      for (final lap in run.laps) {
        final hrText =
            lap.avgHr != null ? ' (평균 ${lap.avgHr!.round()}bpm)' : '';
        buf.writeln(
          '- 랩 #${lap.lapNumber} (${lap.distanceKm.toStringAsFixed(2)}km): ${fmtPace(lap.paceSecPerKm)}/km, 소요 ${fmtDuration(lap.durationSec)}$hrText',
        );
      }
    } else if (run.splits.isNotEmpty) {
      buf.writeln();
      buf.writeln('[구간별 스플릿]');
      for (final s in run.splits) {
        final kmLabel = s.km == s.km.toInt()
            ? '${s.km.toInt()}km'
            : '${s.km.toStringAsFixed(2)}km';
        final hrText =
            s.avgHr != null ? ' (평균 ${s.avgHr!.round()}bpm)' : '';
        buf.writeln('- $kmLabel: ${fmtPace(s.paceSecPerKm)}/km$hrText');
      }
    }

    // 심박존 데이터
    if (run.hrSeries.isNotEmpty) {
      final zones = hrZoneDistribution(run.hrSeries);
      final zLabels = [
        'Z1(회복 <60%)',
        'Z2(지구력 60~70%)',
        'Z3(템포 70~80%)',
        'Z4(역치 80~90%)',
        'Z5(무산소 90%+)',
      ];
      final zoneDetails = <String>[];
      for (var i = 0; i < zones.length; i++) {
        final pct = (zones[i] * 100).round();
        if (pct > 0) {
          zoneDetails.add('${zLabels[i]}: $pct%');
        }
      }
      if (zoneDetails.isNotEmpty) {
        buf.writeln();
        buf.writeln('[심박존 분포]');
        buf.writeln('- ${zoneDetails.join(', ')}');
      }
    }

    // 최근 러닝 평균
    if (recentRuns.isNotEmpty) {
      final avgKm = recentRuns.fold<double>(0, (a, r) => a + r.distanceKm) /
          recentRuns.length;
      final avgPace = averagePaceSecPerKm(recentRuns);
      final validHrs =
          recentRuns.map((r) => r.avgHr).whereType<double>().toList();
      final avgHr = validHrs.isNotEmpty
          ? (validHrs.reduce((a, b) => a + b) / validHrs.length).round()
          : null;

      buf.writeln();
      buf.writeln('[최근 ${recentRuns.length}회 러닝 평균 — 비교용]');
      buf.writeln('- 평균 거리: ${avgKm.toStringAsFixed(2)}km');
      if (avgPace != null) {
        buf.writeln('- 평균 페이스: ${fmtPace(avgPace)}/km');
      }
      if (avgHr != null) {
        buf.writeln('- 평균 심박수: ${avgHr}bpm');
      }
    }

    return buf.toString();
  }

  /// 누적 통계 및 월간 추세를 바탕으로 한 다음 1~2주 맞춤 목표 프롬프트 생성.
  static String buildGoalRecommendationPrompt(
    StatsSummary stats,
    MonthlyStats monthly,
    List<RunSession> recentRuns,
  ) {
    final currentWeek = StatsSummary.weekStart(DateTime.now());
    final weekStarts = List.generate(
      4,
      (index) => currentWeek.subtract(Duration(days: (3 - index) * 7)),
    );
    final weeklyKm = <DateTime, double>{
      for (final week in weekStarts) week: 0,
    };
    final weeklyRuns = <DateTime, int>{
      for (final week in weekStarts) week: 0,
    };
    for (final run in recentRuns) {
      final week = StatsSummary.weekStart(run.startTime);
      if (weeklyKm.containsKey(week)) {
        weeklyKm[week] = weeklyKm[week]! + run.distanceKm;
        weeklyRuns[week] = weeklyRuns[week]! + 1;
      }
    }

    final best1k = stats.best1kPaceSec == null
        ? '기록 없음'
        : '${fmtPace(stats.best1kPaceSec!)}/km';
    final best5k = stats.best5kPaceSec == null
        ? '기록 없음'
        : '${fmtPace(stats.best5kPaceSec!)}/km';
    final recentWeeklyKm = weekStarts
        .map(
          (week) =>
              '${weeklyKm[week]!.toStringAsFixed(1)}km(${weeklyRuns[week]}회)',
        )
        .join(' / ');

    final thisMonthPace = monthly.thisMonthAvgPaceSec != null
        ? '${fmtPace(monthly.thisMonthAvgPaceSec!)}/km'
        : '기록 없음';
    final lastMonthPace = monthly.lastMonthAvgPaceSec != null
        ? '${fmtPace(monthly.lastMonthAvgPaceSec!)}/km'
        : '기록 없음';

    final recentPace = averagePaceSecPerKm(recentRuns.take(5).toList());
    final recentAvgPaceStr =
        recentPace != null ? '${fmtPace(recentPace)}/km' : '기록 없음';

    final buf = StringBuffer();
    buf.writeln(
      '너는 전문 개인 러닝 코치야. 아래 러너의 누적 통계, 월간/주간 추세, 최근 러닝 기록을 심층 분석해서 다음 1~2주간 실천할 맞춤형 목표와 훈련 계획을 제안해줘.',
    );
    buf.writeln(
      '급격한 마일리지 증가로 인한 부상을 방지하고(주간 거리 10% 이내 증편 원칙), 현재 체력 수준에 맞춰 달성 가능하면서도 동기부여가 되는 계획을 세워줘.',
    );
    buf.writeln(
      '이모지나 과장 없이, 명확하고 논리적인 톤으로 아래 3가지 섹션 형식에 맞춰 작성해줘:',
    );
    buf.writeln();
    buf.writeln('🎯 [다음 1~2주 목표]');
    buf.writeln('- 주당 러닝 빈도 및 주간 목표 총 거리 (예: 주 3회, 주간 15~18km)');
    buf.writeln('- 목표 단일 세션 거리 및 목표 페이스 기준');
    buf.writeln();
    buf.writeln('🏃 [추천 세션 구성]');
    buf.writeln('- 회복/이지런, 템포/지속주, 롱런(LSD) 등 주간 2~3회 러닝의 구체적인 세션별 분배 가이드');
    buf.writeln();
    buf.writeln('💡 [코칭 포인트 & 주의사항]');
    buf.writeln('- 심박 관리(Z2/Z3 영역 비중), 페이스 조절, 부상 예방 및 회복에 대한 핵심 조언 1~2개');
    buf.writeln();
    buf.writeln('---');
    buf.writeln('[러닝 이력 및 통계]');
    buf.writeln(
      '- 전체 누적: ${stats.totalRuns}회 / ${stats.totalKm.toStringAsFixed(1)}km',
    );
    buf.writeln(
      '- 주 3회 연속 달성(스트릭): ${stats.currentStreakWeeks}주 (최다 주간 거리 ${stats.maxWeekKm.toStringAsFixed(1)}km)',
    );
    buf.writeln('- 최장 거리(1회): ${stats.longestRunKm.toStringAsFixed(1)}km');
    buf.writeln('- 개인 최고 페이스: 1km $best1k / 5km $best5k');
    buf.writeln('- 최근 5회 평균 페이스: $recentAvgPaceStr');
    buf.writeln(
      '- 이번 달: ${monthly.thisMonthKm.toStringAsFixed(1)}km (${monthly.thisMonthRuns}회, 평균 페이스 $thisMonthPace)',
    );
    buf.writeln(
      '- 지난달: ${monthly.lastMonthKm.toStringAsFixed(1)}km (${monthly.lastMonthRuns}회, 평균 페이스 $lastMonthPace)',
    );
    buf.writeln('- 최근 4주 주간 실적(오래된 순): $recentWeeklyKm');
    return buf.toString();
  }
}
