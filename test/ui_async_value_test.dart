import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:runlog/models/run_session.dart';
import 'package:runlog/providers.dart';
import 'package:runlog/ui/analysis_screen.dart';
import 'package:runlog/ui/home_screen.dart';
import 'package:runlog/ui/run_detail_screen.dart';
import 'package:runlog/ui/runs_screen.dart';
import 'package:runlog/ui/theme.dart';

import 'support/in_memory_run_repository.dart';

RunSession _sampleRun({
  required String id,
  required DateTime startTime,
  double km = 5.0,
  int durationSec = 1800,
  double? avgHr = 150,
  String sourceName = 'Samsung Health',
}) {
  return RunSession(
    id: id,
    startTime: startTime,
    endTime: startTime.add(Duration(seconds: durationSec)),
    distanceM: km * 1000,
    durationSec: durationSec,
    avgHr: avgHr,
    maxHr: 165,
    sourceName: sourceName,
  );
}

Widget _wrapWithScope({
  required Widget child,
  required InMemoryRunRepository repo,
}) {
  return ProviderScope(
    overrides: [
      repoProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: buildTheme(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: child,
    ),
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko', null);
  });

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'RunLog',
      packageName: 'com.stonesilver.runlog',
      version: '1.8.3',
      buildNumber: '28',
      buildSignature: '',
    );
  });

  group('RunsScreen AsyncValue States', () {
    testWidgets('renders CircularProgressIndicator when runsProvider is loading',
        (tester) async {
      final repo = InMemoryRunRepository();
      repo.getAllFuture = Completer<List<RunSession>>().future; // Never resolves

      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunsScreen(),
          repo: repo,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders error text when runsProvider fails with error',
        (tester) async {
      final repo = InMemoryRunRepository();
      repo.getAllError = Exception('DB read failed');

      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunsScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('오류: Exception: DB read failed'), findsOneWidget);
    });

    testWidgets('renders empty notice when runs list is empty', (tester) async {
      final repo = InMemoryRunRepository();
      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunsScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('기록이 없습니다'), findsOneWidget);
    });

    testWidgets('renders list of runs when data is available', (tester) async {
      final repo = InMemoryRunRepository(
        initialRuns: [
          _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1, 20), km: 5.2),
          _sampleRun(id: 'r2', startTime: DateTime(2026, 8, 2, 20), km: 10.0),
        ],
      );

      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunsScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5.20 km'), findsOneWidget);
      expect(find.text('10.00 km'), findsOneWidget);
    });
  });

  group('HomeScreen AsyncValue States', () {
    testWidgets('renders loading state on HomeScreen', (tester) async {
      final repo = InMemoryRunRepository();
      repo.getAllFuture = Completer<List<RunSession>>().future;

      await tester.pumpWidget(
        _wrapWithScope(
          child: const HomeScreen(),
          repo: repo,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('renders error message on HomeScreen', (tester) async {
      final repo = InMemoryRunRepository();
      repo.getAllError = Exception('Connection failed');

      await tester.pumpWidget(
        _wrapWithScope(
          child: const HomeScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('오류: Exception: Connection failed'), findsOneWidget);
    });

    testWidgets('renders empty guidance and import button on HomeScreen',
        (tester) async {
      final repo = InMemoryRunRepository();
      await tester.pumpWidget(
        _wrapWithScope(
          child: const HomeScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('아직 기록이 없어요.\n동기화하거나 이전 기록을 가져와보세요!'),
        findsOneWidget,
      );
      expect(find.text('이전 기록 가져오기'), findsOneWidget);
    });

    testWidgets('renders weekly ring, level, stats, and recent runs on HomeScreen',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = InMemoryRunRepository(
        initialRuns: [
          _sampleRun(id: 'r1', startTime: DateTime.now(), km: 5.0),
          _sampleRun(id: 'r2', startTime: DateTime.now().subtract(const Duration(days: 1)), km: 6.0),
        ],
      );

      await tester.pumpWidget(
        _wrapWithScope(
          child: const HomeScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RunLog'), findsOneWidget);
      expect(find.text('최근 러닝'), findsOneWidget);
      expect(find.text('누적 거리'), findsOneWidget);
      expect(find.text('총 러닝'), findsOneWidget);
    });
  });

  group('RunDetailScreen UI Rendering & Edge Cases', () {
    testWidgets('renders not found notice when runId does not exist in state',
        (tester) async {
      final repo = InMemoryRunRepository();
      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunDetailScreen(runId: 'missing-id'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('기록을 찾을 수 없습니다'), findsOneWidget);
    });

    testWidgets('renders detail cards, AI summary, and dynamics for valid run',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final run = _sampleRun(
        id: 'detail-1',
        startTime: DateTime(2026, 8, 1, 21),
        km: 5.0,
        durationSec: 1800,
        avgHr: 145,
      );
      final repo = InMemoryRunRepository(initialRuns: [run]);
      await repo.saveAiSummary('detail-1', 'AI 코칭: 심박수 관리가 아주 우수했습니다.');

      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunDetailScreen(runId: 'detail-1'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('5.00 km'), findsOneWidget);
      expect(find.text('AI 러닝 요약'), findsOneWidget);
      expect(find.text('AI 코칭: 심박수 관리가 아주 우수했습니다.'), findsOneWidget);
      expect(find.text('러닝 역학 & 심폐 효율'), findsOneWidget);
    });

    testWidgets('shows edit button only for manual records', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final manualRun = _sampleRun(
        id: 'm1',
        startTime: DateTime(2026, 8, 1, 21),
        sourceName: 'manual',
      );
      final hcRun = _sampleRun(
        id: 'hc1',
        startTime: DateTime(2026, 8, 1, 21),
        sourceName: 'Samsung Health',
      );
      final repo = InMemoryRunRepository(initialRuns: [manualRun, hcRun]);

      // Manual Run
      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunDetailScreen(runId: 'm1'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsOneWidget);

      // HC Run
      await tester.pumpWidget(
        _wrapWithScope(
          child: const RunDetailScreen(runId: 'hc1'),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
    });
  });

  group('AnalysisScreen UI Rendering & Edge Cases', () {
    testWidgets('renders empty heatmap guidance when runs list is empty',
        (tester) async {
      final repo = InMemoryRunRepository();
      await tester.pumpWidget(
        _wrapWithScope(
          child: const AnalysisScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('러닝 캘린더'), findsOneWidget);
      expect(find.text('빈 날짜를 눌러 러닝 기록을 추가할 수 있습니다'), findsOneWidget);
      expect(find.text('이번 달'), findsNothing);
    });

    testWidgets('renders GoalRecommendCard and analysis sections when runs exist',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final runs = [
        _sampleRun(id: 'r1', startTime: DateTime(2026, 8, 1, 20), km: 5.0),
        _sampleRun(id: 'r2', startTime: DateTime(2026, 8, 3, 20), km: 5.0),
      ];
      final repo = InMemoryRunRepository(initialRuns: runs);
      await repo.saveGoalRecommendation(
        '추천 목표: 주 3회 15km를 뛰어보세요.',
        DateTime(2026, 8, 1, 10),
      );

      await tester.pumpWidget(
        _wrapWithScope(
          child: const AnalysisScreen(),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('다음 목표'), findsOneWidget);
      expect(find.text('추천 목표: 주 3회 15km를 뛰어보세요.'), findsOneWidget);
      expect(find.text('이번 달'), findsOneWidget);
      expect(find.text('월별 거리 추이'), findsOneWidget);
      expect(find.text('평균 페이스 추이'), findsOneWidget);
      expect(find.text('개인 기록 (PB)'), findsOneWidget);
    });
  });
}

