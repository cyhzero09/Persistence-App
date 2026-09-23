import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../database/database.dart' hide CheckInCategory, CheckInRecord, DiaryEntry, Reminder;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/check_in_category.dart';
import '../models/reminder.dart';
import '../app_version.dart';
import '../update_checker.dart';
import '../cloud_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/background_image.dart';
import '../utils/backup.dart';
import '../utils/browser_launcher.dart';
import '../utils/battery_optimization.dart';
import '../notification_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const themeColors = [
    0xFF009688,
    0xFF1976D2,
    0xFF388E3C,
    0xFFE64A19,
    0xFF7B1FA2,
    0xFFD32F2F,
    0xFF512DA8,
    0xFF00796B,
    0xFFF57C00,
    0xFF5C6BC0,
  ];

  static String colorName(BuildContext context, int color) {
    final l10n = AppLocalizations.of(context);
    return switch (color) {
      0xFF009688 => l10n.colorTeal,
      0xFF1976D2 => l10n.colorBlue,
      0xFF388E3C => l10n.colorGreen,
      0xFFE64A19 => l10n.colorOrange,
      0xFF7B1FA2 => l10n.colorPurple,
      0xFFD32F2F => l10n.colorRed,
      0xFF512DA8 => l10n.colorDeepPurple,
      0xFF00796B => l10n.colorDarkTeal,
      0xFFF57C00 => l10n.colorAmber,
      0xFF5C6BC0 => l10n.colorIndigo,
      _ => l10n.colorTeal,
    };
  }

  static String languageName(String code) {
    return switch (code) {
      'en' => 'English',
      'zh' => '简体中文',
      _ => '繁體中文',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: ListView(
        children: [
          const _SectionHeader(titleKey: 'appearance'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: Text(l10n.themeColor),
            subtitle: Text(colorName(context, settings.themeColor)),
            onTap: () => _showColorPicker(context, ref, settings.themeColor),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: Text(l10n.darkMode),
            subtitle: Text(
              switch (settings.brightness) {
                ThemeMode.light => l10n.whiteMode,
                ThemeMode.dark => l10n.blackMode,
                ThemeMode.system => l10n.followSystem,
              },
            ),
            onTap: () => _showBrightnessPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: Text(l10n.fontSize),
            subtitle: Text('${(settings.fontSize * 100).toInt()}%'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: settings.fontSize > 0.7
                      ? () => ref.read(appSettingsProvider.notifier).setFontSize(settings.fontSize - 0.1)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: settings.fontSize < 1.5
                      ? () => ref.read(appSettingsProvider.notifier).setFontSize(settings.fontSize + 0.1)
                      : null,
                ),
              ],
            ),
          ),
          ListTile(
            leading: settings.backgroundBytes != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.memory(
                      settings.backgroundBytes!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  )
                : const Icon(Icons.image),
            title: Text(l10n.backgroundImage),
            subtitle: Text('${(settings.backgroundOpacity * 100).toInt()}%'),
            onTap: () => _showBackgroundPicker(context, ref),
          ),
          const _BatteryOptimizationTile(),
          const _AutoStartTile(),
          const _ReminderDiagnosticsTile(),
          const Divider(),
          const _SectionHeader(titleKey: 'language'),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(languageName(settings.language)),
            onTap: () => _showLanguagePicker(context, ref),
          ),
          const Divider(),
          const _SectionHeader(titleKey: 'dataManagement'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: Text(l10n.exportBackup),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: Text(l10n.importBackup),
            onTap: () => _importData(context, ref),
          ),
          const Divider(),
          const _SectionHeader(titleKey: 'update'),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: Text(l10n.checkUpdate),
            subtitle: Text(appVersion),
            onTap: () => _checkUpdate(context),
          ),
          const Divider(),
          const _SectionHeader(titleKey: 'account'),
          const _AccountSection(),
          const Divider(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.versionText(appVersion),
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showBackgroundPicker(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(appSettingsProvider);
    double opacity = settings.backgroundOpacity;
    Uint8List? bytes = settings.backgroundBytes;

    Future<void> pickImage() async {
      final xfile = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 85,
      );
      if (xfile == null) return;
      final raw = await xfile.readAsBytes();
      final processed = await processPickedImage(raw);
      if (processed == null) return;
      final ok = await ref.read(appSettingsProvider.notifier).setBackgroundImage(
        base64Encode(processed),
        bytes: processed,
      );
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.imageSaveFailed)));
        return;
      }
      bytes = processed;
    }

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(l10n.backgroundImage),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.maxFinite,
                height: 140,
                decoration: BoxDecoration(
                  color: Theme.of(dialogCtx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: bytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(bytes!, fit: BoxFit.cover, gaplessPlayback: true),
                      )
                    : Center(child: Icon(Icons.image, size: 40, color: Theme.of(dialogCtx).colorScheme.outline)),
              ),
              const SizedBox(height: 12),
              Text(l10n.backgroundOpacity),
              Slider(
                value: opacity.clamp(0.0, 1.0),
                onChanged: bytes == null
                    ? null
                    : (v) {
                        setDialogState(() => opacity = v);
                        ref.read(appSettingsProvider.notifier).setBackgroundOpacity(v);
                      },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () async {
                      await pickImage();
                      if (dialogCtx.mounted) setDialogState(() {});
                    },
                    icon: const Icon(Icons.image),
                    label: Text(l10n.chooseImage),
                  ),
                  TextButton.icon(
                    onPressed: bytes == null
                        ? null
                        : () async {
                            final ok = await ref
                                .read(appSettingsProvider.notifier)
                                .setBackgroundImage('');
                            if (dialogCtx.mounted) {
                              if (!ok) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(content: Text(l10n.imageSaveFailed)),
                                );
                              } else {
                                setDialogState(() => bytes = null);
                              }
                            }
                          },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l10n.clearImage),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, int currentColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx).chooseThemeColor),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: themeColors.map((c) {
              final selected = c == currentColor;
              return GestureDetector(
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setThemeColor(c);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(c),
                    borderRadius: BorderRadius.circular(12),
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: Color(c).withValues(alpha: 0.5), blurRadius: 8)] : null,
                  ),
                  child: selected ? const Icon(Icons.check, color: Colors.white) : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showBrightnessPicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(appSettingsProvider).brightness;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.darkMode),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text(l10n.whiteMode),
              trailing: current == ThemeMode.light ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setBrightness(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(l10n.blackMode),
              trailing: current == ThemeMode.dark ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setBrightness(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(l10n.followSystem),
              trailing: current == ThemeMode.system ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setBrightness(ThemeMode.system);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref) {
    final current = ref.read(appSettingsProvider).language;
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('English'),
              trailing: current == 'en' ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('en');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('简体中文'),
              trailing: current == 'zh' ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('zh');
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('繁體中文'),
              trailing: current == 'zh_TW' ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setLanguage('zh_TW');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final db = ref.read(databaseProvider);
      final jsonStr = await buildBackupJson(db);

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/daily_tracker_backup.json');
      await file.writeAsString(jsonStr);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportedTo(file.path))),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.exportFailed('$e'))),
        );
      }
    }
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final result = await checkForUpdates(appVersion);
    if (!context.mounted) return;
    if (result.errorCode != null) {
      final msg = switch (result.errorCode!) {
        'fetch_failed' => l10n.updateErrorFetch('${result.statusCode}'),
        'empty_version' => l10n.updateErrorEmpty,
        _ => l10n.updateErrorCheck(result.errorDetail ?? ''),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    if (result.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.newVersionFound),
          content: Text(l10n.versionInfo(appVersion, result.latestVersion ?? '')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.close)),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _openDownload(context, result.downloadUrl);
              },
              child: Text(l10n.goDownload),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.upToDate)),
      );
    }
  }

  Future<void> _openDownload(BuildContext context, String? url) async {
    final l10n = AppLocalizations.of(context);
    if (url == null || url.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.downloadFromGitHub)),
        );
      }
      return;
    }
    final ok = await openInBrowser(url);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.downloadFromGitHub)),
      );
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/daily_tracker_backup.json');
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.backupNotFound)),
        );
        return;
      }

      final jsonStr = await file.readAsString();
      final db = ref.read(databaseProvider);
      await applyBackupJson(db, jsonStr);
      // 导入回来的提醒必须重新排进系统闹钟，否则不会响
      await resyncRemindersFromDb(db);

      ref.invalidate(categoriesProvider);
      ref.invalidate(checkInRecordDatesProvider);
      ref.invalidate(diaryEntriesProvider);
      ref.invalidate(remindersProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importComplete)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.importFailed('$e'))),
        );
      }
    }
  }
}

/// 电池优化白名单入口：后台被 ROM 冻结会导致提醒延迟到下次打开应用才触发。
class _BatteryOptimizationTile extends StatefulWidget {
  const _BatteryOptimizationTile();

  @override
  State<_BatteryOptimizationTile> createState() => _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState extends State<_BatteryOptimizationTile>
    with WidgetsBindingObserver {
  late Future<bool> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = isIgnoringBatteryOptimization();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 系统请求对话框关闭回到应用后重新查询白名单状态
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    setState(() => _future = isIgnoringBatteryOptimization());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<bool>(
      future: _future,
      builder: (context, snap) {
        final ok = snap.data ?? true;
        return ListTile(
          leading: Icon(
            ok ? Icons.battery_saver : Icons.battery_alert,
            color: ok ? null : Theme.of(context).colorScheme.error,
          ),
          title: Text(l10n.batteryOptimization),
          subtitle: Text(ok ? l10n.batteryOptimizationOk : l10n.batteryOptimizationBlocked),
          onTap: ok
              ? null
              : () async {
                  await requestIgnoreBatteryOptimization();
                  _reload();
                },
        );
      },
    );
  }
}

/// 「自启动 / 允许后台运行」入口。
/// 国产 ROM 只放行电池优化还不够：没开自启动，划掉应用后系统会冻结闹钟，
/// 提醒要等下次打开应用才补发 —— 这是"关掉软件后不响"的直接原因。
class _AutoStartTile extends StatelessWidget {
  const _AutoStartTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(Icons.restart_alt),
      title: Text(l10n.autoStart),
      subtitle: Text(l10n.autoStartDesc),
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.autoStartDialogTitle),
          content: Text(l10n.autoStartDialogMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(l10n.close),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                // 跳厂商自启动页；没有对应页面时原生侧会退回应用详情页
                openAutoStartSettings();
              },
              child: Text(l10n.goToSettings),
            ),
          ],
        ),
      ),
    );
  }
}

/// 提醒诊断：一眼看出「关掉软件后不响」卡在哪一环。
/// 通知权限、精确闹钟任一缺失都会让提醒被系统延迟或丢弃。
class _ReminderDiagnosticsTile extends StatefulWidget {
  const _ReminderDiagnosticsTile();

  @override
  State<_ReminderDiagnosticsTile> createState() => _ReminderDiagnosticsTileState();
}

class _ReminderDiagnosticsTileState extends State<_ReminderDiagnosticsTile>
    with WidgetsBindingObserver {
  late Future<_DiagInfo> _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _future = _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 从系统设置授权回来（或新建提醒后）重新统计
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<_DiagInfo> _load() async {
    final service = NotificationService();
    return _DiagInfo(
      notifications: await service.areNotificationsEnabled(),
      exact: await service.canScheduleExact(),
      pending: await service.pendingCount(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<_DiagInfo>(
      future: _future,
      builder: (context, snap) {
        final info = snap.data;
        final ok = info == null || (info.notifications && info.exact);
        return ListTile(
          leading: Icon(
            ok ? Icons.notifications_active : Icons.notifications_off,
            color: ok ? null : cs.error,
          ),
          title: Text(l10n.reminderDiagnostics),
          subtitle: Text(info == null
              ? '...'
              : l10n.diagSummary(
                  info.notifications ? l10n.diagGranted : l10n.diagDenied,
                  info.exact ? l10n.diagGranted : l10n.diagDenied,
                  '${info.pending}',
                )),
          onTap: info == null
              ? null
              : () async {
                  final service = NotificationService();
                  if (!info.notifications) {
                    await service.requestNotificationsPermission();
                  } else if (!info.exact) {
                    await service.requestExactAlarmPermission();
                  }
                  _reload();
                },
        );
      },
    );
  }
}

class _DiagInfo {
  final bool notifications;
  final bool exact;
  final int pending;
  const _DiagInfo({required this.notifications, required this.exact, required this.pending});
}

/// Google 账号 + 云端存档（Firebase Auth + Firestore）。
/// 云端未配置（缺 android/app/google-services.json）时只显示一行提示，不影响其它功能。
/// 存档结构复用本地导出/导入用的 [buildBackupJson] / [applyBackupJson]。
class _AccountSection extends ConsumerStatefulWidget {
  const _AccountSection();

  @override
  ConsumerState<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<_AccountSection> {
  final _cloud = CloudService();
  bool _busy = false;
  bool _infoLoaded = false;
  CloudBackupInfo? _info;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  /// 读取云端存档的元信息（上次备份时间/大小）
  Future<void> _loadInfo() async {
    if (!_cloud.isReady || _cloud.user == null) return;
    try {
      final info = await _cloud.fetchBackupInfo();
      if (!mounted) return;
      setState(() {
        _info = info;
        _infoLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _infoLoaded = true);
    }
  }

  String _errorText(AppLocalizations l10n, Object e) {
    if (e is CloudException) {
      return switch (e.code) {
        'canceled' => l10n.signInCanceled,
        'notConfigured' => l10n.cloudNotConfigured,
        'notSignedIn' => l10n.notSignedIn,
        'tooLarge' => l10n.backupTooLarge,
        'noBackup' => l10n.noCloudBackup,
        _ => l10n.cloudOpFailed(e.detail ?? e.code),
      };
    }
    return l10n.cloudOpFailed('$e');
  }

  Future<bool> _confirm(String message) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirm)),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _run(Future<void> Function() action, String successText) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(successText)));
      await _loadInfo();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_errorText(l10n, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn() => _run(() => _cloud.signIn(), AppLocalizations.of(context).signInWithGoogle);

  Future<void> _signOut() async {
    await _run(() async {
      await _cloud.signOut();
      _info = null;
      _infoLoaded = false;
    }, AppLocalizations.of(context).signOut);
  }

  Future<void> _upload() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.uploadBackupConfirm)) return;
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    await _run(() async {
      await _cloud.uploadBackup(await buildBackupJson(db));
    }, l10n.uploadSuccess);
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context);
    if (!await _confirm(l10n.restoreConfirm)) return;
    if (!mounted) return;
    final db = ref.read(databaseProvider);
    await _run(() async {
      final jsonStr = await _cloud.downloadBackup();
      if (jsonStr == null) throw const CloudException('noBackup');
      await applyBackupJson(db, jsonStr);
      // 恢复回来的提醒必须重新排进系统闹钟，否则不会响
      await resyncRemindersFromDb(db);
    }, l10n.restoreSuccess);
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(remindersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (!_cloud.isReady) {
      return ListTile(
        leading: const Icon(Icons.cloud_off),
        title: Text(l10n.cloudAccount),
        subtitle: Text(l10n.cloudNotConfigured),
        enabled: false,
      );
    }

    final user = _cloud.user;
    if (user == null) {
      return ListTile(
        leading: const Icon(Icons.login),
        title: Text(l10n.signInWithGoogle),
        subtitle: Text(l10n.cloudAccount),
        onTap: _busy ? null : _signIn,
      );
    }

    final photoUrl = user.photoURL;
    final subtitle = _info == null
        ? (_infoLoaded ? l10n.noCloudBackup : '...')
        : '${l10n.lastBackupAt(DateFormat('yyyy/M/d HH:mm', intlLocaleOf(context)).format(_info!.updatedAt))}'
            ' · ${(_info!.sizeBytes / 1024).toStringAsFixed(1)} KB';

    return Column(
      children: [
        ListTile(
          leading: photoUrl != null
              ? CircleAvatar(backgroundImage: NetworkImage(photoUrl))
              : const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user.displayName ?? user.email ?? ''),
          subtitle: Text(user.email ?? ''),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_upload),
          title: Text(l10n.uploadBackup),
          subtitle: Text(subtitle),
          onTap: _busy ? null : _upload,
        ),
        ListTile(
          leading: const Icon(Icons.cloud_download),
          title: Text(l10n.restoreFromCloud),
          enabled: _info != null && !_busy,
          onTap: _busy ? null : _restore,
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: Text(l10n.signOut),
          onTap: _busy ? null : _signOut,
        ),
        if (_busy) const LinearProgressIndicator(),
      ],
    );
  }
}

/// 把库里所有未完成的提醒 + 开启了提醒的打卡项目重新排进系统闹钟。
/// 本地导入/云端恢复之后必须调用，否则恢复回来的提醒不会触发。
Future<void> resyncRemindersFromDb(AppDatabase db) async {
  final rows = await db.select(db.reminders).get();
  final catRows = await db.select(db.checkInCategories).get();
  await NotificationService().resyncPending(
    rows
        .map((r) => Reminder(
              id: r.id,
              title: r.title,
              dateTime: r.reminderDateTime,
              repeatWeekdays: r.repeatWeekdays,
              repeatEndDate: r.repeatEndDate,
              categoryId: r.categoryId,
              isCompleted: r.isCompleted,
            ))
        .toList(),
    categories: catRows
        .map((c) => CheckInCategory(
              id: c.id,
              name: c.name,
              emoji: c.emoji,
              description: c.description,
              startTime: c.startTime,
              endTime: c.endTime,
              repeatWeekdays: c.repeatWeekdays,
              reminderTime: c.reminderTime,
              isDefault: c.isDefault,
            ))
        .toList(),
  );
}

class _SectionHeader extends StatelessWidget {
  final String titleKey;
  const _SectionHeader({required this.titleKey});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (titleKey) {
      'appearance' => l10n.appearance,
      'language' => l10n.language,
      'dataManagement' => l10n.dataManagement,
      'update' => l10n.update,
      _ => l10n.account,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      )),
    );
  }
}
