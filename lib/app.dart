import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pages/home_page.dart';
import 'pages/content_page.dart';
import 'pages/settings_page.dart';
import 'widgets/bottom_nav.dart';
import 'providers/app_settings_provider.dart';
import 'l10n/generated/app_localizations.dart';

Locale _localeFromCode(String code) {
  final parts = code.split('_');
  return parts.length > 1 ? Locale(parts[0], parts[1]) : Locale(parts[0]);
}

/// 有背景图时让 Scaffold/AppBar/底栏透出背景
ThemeData _applyTransparentBackground(ThemeData theme) {
  return theme.copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: theme.appBarTheme.copyWith(
      backgroundColor: Colors.transparent,
      scrolledUnderElevation: 0,
    ),
    navigationBarTheme: theme.navigationBarTheme.copyWith(
      backgroundColor: Colors.transparent,
    ),
  );
}

class DailyTrackerApp extends ConsumerStatefulWidget {
  const DailyTrackerApp({super.key});

  @override
  ConsumerState<DailyTrackerApp> createState() => _DailyTrackerAppState();
}

class _DailyTrackerAppState extends ConsumerState<DailyTrackerApp> {
  bool _languageDialogShown = false;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final hasBg = settings.initialized &&
        settings.backgroundImage.isNotEmpty &&
        settings.backgroundBytes != null;
    return MaterialApp(
      title: 'Daily Tracker',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navigatorKey,
      locale: _localeFromCode(settings.language),
      supportedLocales: const [Locale('en'), Locale('zh'), Locale('zh', 'TW')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      themeMode: settings.brightness,
      theme: hasBg
          ? _applyTransparentBackground(ThemeData(
              colorSchemeSeed: Color(settings.themeColor),
              useMaterial3: true,
            ))
          : ThemeData(
              colorSchemeSeed: Color(settings.themeColor),
              useMaterial3: true,
            ),
      darkTheme: hasBg
          ? _applyTransparentBackground(ThemeData(
              colorSchemeSeed: Color(settings.themeColor),
              useMaterial3: true,
              brightness: Brightness.dark,
            ))
          : ThemeData(
              colorSchemeSeed: Color(settings.themeColor),
              useMaterial3: true,
              brightness: Brightness.dark,
            ),
      builder: (context, child) {
        if (settings.initialized && !settings.languageChosen && !_languageDialogShown) {
          _languageDialogShown = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            // builder 的 context 位于 Navigator 之上，showDialog 必须用 navigator 的 context
            final navContext = _navigatorKey.currentContext;
            if (navContext != null) _showLanguageDialog(navContext);
          });
        }
        Widget effectiveChild = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(settings.fontSize),
          ),
          child: child!,
        );
        if (hasBg) {
          // 全局背景层垫底，页面内容浮于其上
          effectiveChild = Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Opacity(
                    opacity: settings.backgroundOpacity.clamp(0.0, 1.0),
                    child: Image.memory(
                      settings.backgroundBytes!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
              effectiveChild,
            ],
          );
        }
        return effectiveChild;
      },
      home: const MainShell(),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context) async {
    String selected = ref.read(appSettingsProvider).language;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx);
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: Text(l10n.welcomeTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.welcomeMessage),
                const SizedBox(height: 8),
                RadioListTile<String>(
                  title: const Text('English'),
                  value: 'en',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v!),
                ),
                RadioListTile<String>(
                  title: const Text('简体中文'),
                  value: 'zh',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v!),
                ),
                RadioListTile<String>(
                  title: const Text('繁體中文'),
                  value: 'zh_TW',
                  groupValue: selected,
                  onChanged: (v) => setDialogState(() => selected = v!),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () async {
                  final notifier = ref.read(appSettingsProvider.notifier);
                  await notifier.setLanguage(selected);
                  await notifier.markLanguageChosen();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.continueButton),
              ),
            ],
          ),
        );
      },
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
