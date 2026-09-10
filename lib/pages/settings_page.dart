import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path_provider/path_provider.dart';
import '../database/database.dart' hide CheckInCategory, CheckInRecord, DiaryEntry, Reminder;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';
import '../app_version.dart';
import '../update_checker.dart';
import '../l10n/generated/app_localizations.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/background_image.dart';
import '../utils/browser_launcher.dart';
import '../utils/battery_optimization.dart';

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
            subtitle: const Text(appVersion),
            onTap: () => _checkUpdate(context),
          ),
          const Divider(),
          const _SectionHeader(titleKey: 'account'),
          ListTile(
            leading: const Icon(Icons.login),
            title: Text(l10n.loginGoogle),
            subtitle: Text(l10n.comingSoon),
            enabled: false,
          ),
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
      final cats = await db.select(db.checkInCategories).get();
      final records = await db.select(db.checkInRecords).get();
      final diaries = await db.select(db.diaryEntries).get();
      final reminders = await db.select(db.reminders).get();

      final data = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'categories': cats.map((r) => CheckInCategory(id: r.id, name: r.name, emoji: r.emoji, description: r.description, startTime: r.startTime, endTime: r.endTime, repeatWeekdays: r.repeatWeekdays, isDefault: r.isDefault).toJson()).toList(),
        'records': records.map((r) => CheckInRecord(id: r.id, categoryId: r.categoryId, date: r.date, isCompleted: r.isCompleted, note: r.note, completedAt: r.completedAt).toJson()).toList(),
        'diaries': diaries.map((r) => DiaryEntry(id: r.id, date: r.date, title: r.title, content: r.content, checkInRecordId: r.checkInRecordId).toJson()).toList(),
        'reminders': reminders.map((r) => Reminder(id: r.id, title: r.title, dateTime: r.reminderDateTime, repeatWeekdays: r.repeatWeekdays, repeatEndDate: r.repeatEndDate, categoryId: r.categoryId, isCompleted: r.isCompleted).toJson()).toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/daily_tracker_backup.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

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

      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final db = ref.read(databaseProvider);

      await db.delete(db.reminders).go();
      await db.delete(db.diaryEntries).go();
      await db.delete(db.checkInRecords).go();
      await db.delete(db.checkInCategories).go();

      for (final c in json['categories'] as List) {
        final m = CheckInCategory.fromJson(c as Map<String, dynamic>);
        await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
          name: m.name, emoji: m.emoji, description: m.description != null ? Value(m.description!) : const Value.absent(), startTime: m.startTime != null ? Value(m.startTime!) : const Value.absent(), endTime: m.endTime != null ? Value(m.endTime!) : const Value.absent(), repeatWeekdays: m.repeatWeekdays != null ? Value(m.repeatWeekdays!) : const Value.absent(), isDefault: Value(m.isDefault),
        ));
      }
      for (final r in json['records'] as List) {
        final m = CheckInRecord.fromJson(r as Map<String, dynamic>);
        await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: m.categoryId, date: m.date, isCompleted: Value(m.isCompleted), note: Value(m.note), completedAt: m.completedAt != null ? Value(m.completedAt!) : const Value.absent(),
        ));
      }
      for (final d in json['diaries'] as List) {
        final m = DiaryEntry.fromJson(d as Map<String, dynamic>);
        await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
          date: m.date, title: m.title != null ? Value(m.title!) : const Value.absent(), content: m.content, checkInRecordId: Value(m.checkInRecordId),
        ));
      }
      for (final r in json['reminders'] as List) {
        final m = Reminder.fromJson(r as Map<String, dynamic>);
        await db.into(db.reminders).insert(RemindersCompanion.insert(
          title: m.title, reminderDateTime: m.dateTime, repeatWeekdays: m.repeatWeekdays != null ? Value(m.repeatWeekdays!) : const Value.absent(),
          repeatEndDate: m.repeatEndDate != null ? Value(m.repeatEndDate!) : const Value.absent(),
          isCompleted: Value(m.isCompleted),
          categoryId: m.categoryId != null ? Value(m.categoryId!) : const Value.absent(),
        ));
      }

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
