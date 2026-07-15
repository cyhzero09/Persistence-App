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
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(title: '打卡項目'),
          categoriesAsync.when(
            data: (cats) => Column(
              children: [
                ...cats.map((cat) => ListTile(
                  leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(cat.name),
                  subtitle: cat.isDefault ? const Text('預設') : null,
                  trailing: cat.isDefault ? null : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditCategoryDialog(context, ref, cat),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteCategory(ref, cat.id),
                      ),
                    ],
                  ),
                )),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('載入失敗')),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新增項目'),
            onTap: () => _showAddCategoryDialog(context, ref),
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
          const _SectionHeader(title: '帳號'),
          const ListTile(
            leading: Icon(Icons.login),
            title: Text('登入 Google 帳號'),
            subtitle: Text('即將推出'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(WidgetRef ref, int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String emoji = '📌';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增打卡項目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text('選擇圖示：$emoji', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: '🏃📚💧🧘💪🎵✍️🍎☕🎮📝🛌🎯🌈'.split('').map((e) => GestureDetector(
                  onTap: () => setDialogState(() => emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: emoji == e ? Colors.teal : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty ? null : () async {
                final db = ref.read(databaseProvider);
                await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
                  name: nameController.text.trim(),
                  emoji: emoji,
                ));
                ref.invalidate(categoriesProvider);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, CheckInCategory category) {
    final nameController = TextEditingController(text: category.name);
    String emoji = category.emoji;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('編輯打卡項目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text('選擇圖示：$emoji', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: '🏃📚💧🧘💪🎵✍️🍎☕🎮📝🛌🎯🌈'.split('').map((e) => GestureDetector(
                  onTap: () => setDialogState(() => emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: emoji == e ? Colors.teal : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty ? null : () async {
                final db = ref.read(databaseProvider);
                await (db.update(db.checkInCategories)
                  ..where((t) => t.id.equals(category.id)))
                  .write(CheckInCategoriesCompanion(
                    name: Value(nameController.text.trim()),
                    emoji: Value(emoji),
                  ));
                ref.invalidate(categoriesProvider);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
              },
              child: const Text('儲存'),
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
        'categories': cats.map((r) => CheckInCategory(id: r.id, name: r.name, emoji: r.emoji, isDefault: r.isDefault).toJson()).toList(),
        'records': records.map((r) => CheckInRecord(id: r.id, categoryId: r.categoryId, date: r.date, isCompleted: r.isCompleted, note: r.note).toJson()).toList(),
        'diaries': diaries.map((r) => DiaryEntry(id: r.id, date: r.date, content: r.content, checkInRecordId: r.checkInRecordId).toJson()).toList(),
        'reminders': reminders.map((r) => Reminder(id: r.id, title: r.title, dateTime: r.reminderDateTime, categoryId: r.categoryId, isCompleted: r.isCompleted).toJson()).toList(),
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
          name: m.name, emoji: m.emoji, isDefault: Value(m.isDefault),
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
          date: m.date, content: m.content, checkInRecordId: Value(m.checkInRecordId),
        ));
      }
      for (final r in json['reminders'] as List) {
        final m = Reminder.fromJson(r as Map<String, dynamic>);
        await db.into(db.reminders).insert(RemindersCompanion.insert(
          title: m.title, reminderDateTime: m.dateTime, isCompleted: Value(m.isCompleted),
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
