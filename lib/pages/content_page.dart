import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder, DiaryEntry;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../notification_service.dart';
import '../models/check_in_category.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';
import 'diary_detail_page.dart';
import 'diary_edit_page.dart';
import 'category_detail_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';
import '../utils/confirm_delete.dart';
import '../widgets/add_sheets.dart';

const _emojis = [
  '🏃','📚','💧','🧘','💪','🎵','✍','🍎','☕','🎮','📝','🛌','🎯','🌈',
  '💻','📱','🎨','🎬','🎧','🏋','🚴','🏊','🥗','🧠','💊','🧹','🎁','💡',
];

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.contentTitle),
          bottom: TabBar(
            tabs: [
              Tab(text: l10n.checkInItemsTab),
              Tab(text: l10n.tabDiary),
              Tab(text: l10n.tabReminder),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _CategoriesTab(),
            _DiaryTab(),
            _RemindersTab(),
          ],
        ),
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (_) => const AddCategorySheet(),
        ),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (cats) => cats.isEmpty
            ? Center(child: Text(AppLocalizations.of(context).noCheckInItems))
            : ListView.builder(
                itemCount: cats.length,
                itemBuilder: (_, i) {
                  final cat = cats[i];
                  return ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CategoryDetailPage(category: cat),
                    )),
                    leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                    title: Text(cat.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cat.description != null && cat.description!.isNotEmpty)
                          Text(cat.description!, style: const TextStyle(fontSize: 13)),
                        if (cat.isDefault) Text(AppLocalizations.of(context).defaultLabel, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditCategoryDialog(context, ref, cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteCategory(context, ref, cat.id),
                        ),
                      ],
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Future<void> _deleteCategory(BuildContext context, WidgetRef ref, int id) async {
    if (!await confirmDelete(context)) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordsForCategoryProvider(id));
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showEditCategoryDialog(BuildContext context, WidgetRef ref, CheckInCategory category) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AddCategorySheet(category: category),
    );
  }
}

class _DiaryTab extends ConsumerWidget {
  const _DiaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryAsync = ref.watch(diaryEntriesProvider);
    return Scaffold(
      body: diaryAsync.when(
        data: (entries) => entries.isEmpty
            ? Center(child: Text(AppLocalizations.of(context).noDiary))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final dt = DateTime.parse(entry.date);
                  return ListTile(
                    title: Text(
                      entry.title ?? entry.content.split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(DateFormat('yyyy/M/d HH:mm', intlLocaleOf(context)).format(dt)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.checkInRecordId != null)
                          const Icon(Icons.check_circle_outline, size: 16),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editDiary(context, ref, entry),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteDiary(context, ref, entry.id),
                        ),
                      ],
                    ),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DiaryDetailPage(entry: entry),
                    )),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (_) => const AddDiarySheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _editDiary(BuildContext context, WidgetRef ref, DiaryEntry entry) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DiaryEditPage(entry: entry),
    ));
  }

  Future<void> _deleteDiary(BuildContext context, WidgetRef ref, int id) async {
    if (!await confirmDelete(context)) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.diaryEntries)..where((t) => t.id.equals(id))).go();
    ref.invalidate(diaryEntriesProvider);
  }
}

class _RemindersTab extends ConsumerWidget {
  const _RemindersTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);
    return Scaffold(
      body: remindersAsync.when(
        data: (reminders) => reminders.isEmpty
            ? Center(child: Text(AppLocalizations.of(context).noReminders))
            : ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (_, i) => Dismissible(
                  key: ValueKey(reminders[i].id),
                  direction: DismissDirection.endToStart,
                  confirmDismiss: (_) => confirmDelete(context),
                  onDismissed: (_) => ref.read(reminderNotifierProvider).deleteReminder(reminders[i].id),
                  child: _ReminderTile(reminder: reminders[i]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => const AddReminderSheet(),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final dt = DateTime.parse(reminder.dateTime);
    return ListTile(
      title: Text(reminder.title, style: TextStyle(
        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
      )),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('M/d HH:mm', intlLocaleOf(context)).format(dt)),
          if (reminder.isRepeating) ...[
            Text(
              '${l10n.repeat} ${l10n.repeatWeekly(reminder.repeatWeekdays!.split(',').map((s) => chipWeekdayLabels(context)[int.parse(s)]).join(listSeparatorOf(context)))}',
              style: const TextStyle(fontSize: 12),
            ),
            if (reminder.repeatEndDate != null)
              Text(l10n.untilDate(reminder.repeatEndDate!), style: const TextStyle(fontSize: 12))
            else
              Text(l10n.forever, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      leading: Checkbox(
        value: reminder.isCompleted,
        onChanged: (v) => ref.read(reminderNotifierProvider).toggleReminder(reminder.id, v ?? false),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editReminder(context, ref, reminder),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (await confirmDelete(context)) {
                await ref.read(reminderNotifierProvider).deleteReminder(reminder.id);
              }
            },
          ),
        ],
      ),
    );
  }

  void _editReminder(BuildContext context, WidgetRef ref, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => AddReminderSheet(editReminder: reminder),
    );
  }
}


