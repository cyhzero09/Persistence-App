import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_page.dart';
import 'pages/content_page.dart';
import 'pages/settings_page.dart';
import 'widgets/bottom_nav.dart';
import 'providers/app_settings_provider.dart';

class DailyTrackerApp extends ConsumerWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      title: '日常追蹤',
      debugShowCheckedModeBanner: false,
      themeMode: settings.brightness,
      theme: ThemeData(
        colorSchemeSeed: Color(settings.themeColor),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Color(settings.themeColor),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontSize),
          ),
          child: child!,
        );
      },
      home: const MainShell(),
    );
  }
}

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    ContentPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
