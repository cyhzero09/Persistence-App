import 'dart:convert';
import 'dart:io';
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

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const themeColors = [
    (0xFF009688, 'Teal'),
    (0xFF1976D2, 'Blue'),
    (0xFF388E3C, 'Green'),
    (0xFFE64A19, 'Orange'),
    (0xFF7B1FA2, 'Purple'),
    (0xFFD32F2F, 'Red'),
    (0xFF512DA8, 'Deep Purple'),
    (0xFF00796B, 'Dark Teal'),
    (0xFFF57C00, 'Amber'),
    (0xFF5C6BC0, 'Indigo'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(title: '外觀'),
          ListTile(
            leading: const Icon(Icons.palette),
            title: const Text('主題顏色'),
            subtitle: Text(
              themeColors.firstWhere((c) => c.$1 == settings.themeColor, orElse: () => (0xFF009688, 'Teal')).$2,
            ),
            onTap: () => _showColorPicker(context, ref, settings.themeColor),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('深色模式'),
            subtitle: Text(
              switch (settings.brightness) {
                ThemeMode.light => '白色',
                ThemeMode.dark => '黑色',
                ThemeMode.system => '跟隨系統',
              },
            ),
            onTap: () => _showBrightnessPicker(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('字體大小'),
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
          const Divider(),
          const _SectionHeader(title: '資料管理'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('匯出備份'),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('匯入備份'),
            onTap: () => _importData(context, ref),
          ),
          const Divider(),
          const _SectionHeader(title: '更新'),
          ListTile(
            leading: const Icon(Icons.system_update),
            title: const Text('檢查更新'),
            subtitle: const Text(appVersion),
            onTap: () => _checkUpdate(context),
          ),
          const Divider(),
          const _SectionHeader(title: '帳號'),
          const ListTile(
            leading: Icon(Icons.login),
            title: Text('登入 Google 帳號'),
            subtitle: Text('即將推出'),
            enabled: false,
          ),
          const Divider(),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('版本 $appVersion',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showColorPicker(BuildContext context, WidgetRef ref, int currentColor) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('選擇主題顏色'),
        content: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: themeColors.map((c) {
              final selected = c.$1 == currentColor;
              return GestureDetector(
                onTap: () {
                  ref.read(appSettingsProvider.notifier).setThemeColor(c.$1);
                  Navigator.pop(ctx);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(c.$1),
                    borderRadius: BorderRadius.circular(12),
                    border: selected ? Border.all(color: Colors.white, width: 3) : null,
                    boxShadow: selected ? [BoxShadow(color: Color(c.$1).withValues(alpha: 0.5), blurRadius: 8)] : null,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('深色模式'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('白色'),
              trailing: current == ThemeMode.light ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setBrightness(ThemeMode.light);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('黑色'),
              trailing: current == ThemeMode.dark ? const Icon(Icons.check) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).setBrightness(ThemeMode.dark);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('跟隨系統'),
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

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    try {
      final db = ref.read(databaseProvider);
      final cats = await db.select(db.checkInCategories).get();
      final records = await db.select(db.checkInRecords).get();
      final diaries = await db.select(db.diaryEntries).get();
      final reminders = await db.select(db.reminders).get();

      final data = {
        'version': 1,
        'exportDate': DateTime.now().toIso8601String(),
        'categories': cats.map((r) => CheckInCategory(id: r.id, name: r.name, emoji: r.emoji, description: r.description, isDefault: r.isDefault).toJson()).toList(),
        'records': records.map((r) => CheckInRecord(id: r.id, categoryId: r.categoryId, date: r.date, isCompleted: r.isCompleted, note: r.note).toJson()).toList(),
        'diaries': diaries.map((r) => DiaryEntry(id: r.id, date: r.date, title: r.title, content: r.content, checkInRecordId: r.checkInRecordId).toJson()).toList(),
        'reminders': reminders.map((r) => Reminder(id: r.id, title: r.title, dateTime: r.reminderDateTime, repeatWeekdays: r.repeatWeekdays, repeatEndDate: r.repeatEndDate, categoryId: r.categoryId, isCompleted: r.isCompleted).toJson()).toList(),
      };

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/daily_tracker_backup.json');
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已匯出到 ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯出失敗：$e')),
        );
      }
    }
  }

  Future<void> _checkUpdate(BuildContext context) async {
    final result = await checkForUpdates(appVersion);
    if (!context.mounted) return;
    if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.error!)));
      return;
    }
    if (result.hasUpdate) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('發現新版本'),
          content: Text('目前版本：$appVersion\n最新版本：${result.latestVersion}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('關閉')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('請至 GitHub Releases 下載新版本')),
                );
              },
              child: const Text('前往下載'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('目前為最新版本')),
      );
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/daily_tracker_backup.json');
      if (!await file.exists()) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('找不到備份檔案')),
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
          name: m.name, emoji: m.emoji, description: m.description != null ? Value(m.description!) : const Value.absent(), isDefault: Value(m.isDefault),
        ));
      }
      for (final r in json['records'] as List) {
        final m = CheckInRecord.fromJson(r as Map<String, dynamic>);
        await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: m.categoryId, date: m.date, isCompleted: Value(m.isCompleted), note: Value(m.note),
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
          const SnackBar(content: Text('匯入完成')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('匯入失敗：$e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
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
