import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/run_repository.dart';
import 'providers.dart';
import 'ui/achievements_screen.dart';
import 'ui/analysis_screen.dart';
import 'ui/home_screen.dart';
import 'ui/runs_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  final repo = await HiveRunRepository.open();

  runApp(
    ProviderScope(
      overrides: [repoProvider.overrideWithValue(repo)],
      child: const RunLogApp(),
    ),
  );
}

class RunLogApp extends StatelessWidget {
  const RunLogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RunLog',
      theme: buildTheme(),
      locale: const Locale('ko'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko'), Locale('en')],
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _screens = [
    HomeScreen(),
    RunsScreen(),
    AnalysisScreen(),
    AchievementsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.list_alt_outlined), label: '기록'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined), label: '분석'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events_outlined), label: '업적'),
        ],
      ),
    );
  }
}
