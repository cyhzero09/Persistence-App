import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder, DiaryEntry;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/check_in_category.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';
import 'diary_detail_page.dart';
import 'diary_edit_page.dart';
import 'category_detail_page.dart';

const _emojis = [
  '🏃','📚','💧','🧘','💪','🎵','✍','🍎','☕','🎮','📝','🛌','🎯','🌈',
  '💻','📱','🎨','🎬','🎧','🏋','🚴','🏊','🥗','🧠','💊','🧹','🎁','💡',
];

class ContentPage extends ConsumerWidget {
  const ContentPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('內容'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '打卡項目'),
              Tab(text: '日記'),
              Tab(text: '提醒'),
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
        onPressed: () => _showAddCategoryDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categoriesAsync.when(
        data: (cats) => cats.isEmpty
            ? const Center(child: Text('尚無打卡項目'))
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
                        if (cat.isDefault) const Text('預設', style: TextStyle(fontSize: 12)),
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
                          onPressed: () => _deleteCategory(ref, cat.id),
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

  Future<void> _deleteCategory(WidgetRef ref, int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    String emoji = '📌';
    bool addReminder = false;
    DateTime reminderTime = DateTime.now().add(const Duration(hours: 9));
    final selectedWeekdays = <int>{};
    bool isForever = true;
    DateTime? repeatEndDate;

    bool emojiExpanded = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增打卡項目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '簡介（可選）', border: OutlineInputBorder(), hintText: '例如：每天跑30分鐘'),
                ),
                const SizedBox(height: 12),
                Text('選擇圖示：$emoji', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ..._emojis.take(emojiExpanded ? _emojis.length : 8).map((e) => GestureDetector(
                      onTap: () => setDialogState(() => emoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emoji == e ? Theme.of(context).colorScheme.primaryContainer : null,
                          border: Border.all(color: emoji == e ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    )),
                    if (!emojiExpanded)
                      GestureDetector(
                        onTap: () => setDialogState(() => emojiExpanded = true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('+${_emojis.length - 8}', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => setDialogState(() => emojiExpanded = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.unfold_less, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('新增提醒'),
                    Switch(
                      value: addReminder,
                      onChanged: (v) => setDialogState(() => addReminder = v),
                    ),
                  ],
                ),
                if (addReminder) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(DateFormat('HH:mm', 'zh-TW').format(reminderTime)),
                    leading: const Icon(Icons.access_time),
                    onTap: () async {
                      final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(reminderTime));
                      if (tm != null) setDialogState(() => reminderTime = DateTime(reminderTime.year, reminderTime.month, reminderTime.day, tm.hour, tm.minute));
                    },
                  ),
                  const Text('重複：', style: TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 4,
                    children: List.generate(7, (i) => FilterChip(
                      label: Text(['一','二','三','四','五','六','日'][i]),
                      selected: selectedWeekdays.contains(i),
                      onSelected: (v) {
                        setDialogState(() {
                          if (v) { selectedWeekdays.add(i); } else { selectedWeekdays.remove(i); }
                        });
                      },
                    )),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('結束：'),
                      TextButton(
                        onPressed: () => setDialogState(() {
                          isForever = !isForever;
                          if (!isForever && repeatEndDate == null) {
                            repeatEndDate = DateTime.now().add(const Duration(days: 30));
                          }
                        }),
                        child: Text(isForever ? '永遠' : DateFormat('yyyy/M/d').format(repeatEndDate ?? DateTime.now().add(const Duration(days: 30)))),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty ? null : () async {
                final db = ref.read(databaseProvider);
                final catId = await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
                  name: nameController.text.trim(),
                  emoji: emoji,
                  description: descController.text.trim().isNotEmpty ? Value(descController.text.trim()) : const Value.absent(),
                ));
                if (addReminder) {
                  final weekdaysStr = selectedWeekdays.isNotEmpty ? selectedWeekdays.join(',') : null;
                  await db.into(db.reminders).insert(RemindersCompanion.insert(
                    title: nameController.text.trim(),
                    reminderDateTime: reminderTime.toIso8601String(),
                    repeatWeekdays: weekdaysStr != null ? Value(weekdaysStr) : const Value.absent(),
                    repeatEndDate: isForever ? const Value.absent() : Value(DateFormat('yyyy-MM-dd').format(repeatEndDate!)),
                    categoryId: Value(catId),
                  ));
                }
                ref.invalidate(categoriesProvider);
                ref.invalidate(remindersProvider);
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
    final descController = TextEditingController(text: category.description ?? '');
    String emoji = category.emoji;
    bool emojiExpanded = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('編輯打卡項目'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: '簡介（可選）', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                Text('選擇圖示：$emoji', style: const TextStyle(fontSize: 18)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ..._emojis.take(emojiExpanded ? _emojis.length : 8).map((e) => GestureDetector(
                      onTap: () => setDialogState(() => emoji = e),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emoji == e ? Theme.of(context).colorScheme.primaryContainer : null,
                          border: Border.all(color: emoji == e ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 24)),
                      ),
                    )),
                    if (!emojiExpanded)
                      GestureDetector(
                        onTap: () => setDialogState(() => emojiExpanded = true),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('+${_emojis.length - 8}', style: TextStyle(fontSize: 14, color: Theme.of(context).colorScheme.primary)),
                        ),
                      )
                    else
                      GestureDetector(
                        onTap: () => setDialogState(() => emojiExpanded = false),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Theme.of(context).colorScheme.outline),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.unfold_less, size: 20, color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                  ],
                ),
              ],
            ),
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
                    description: descController.text.trim().isNotEmpty ? Value(descController.text.trim()) : const Value.absent(),
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
}

class _DiaryTab extends ConsumerWidget {
  const _DiaryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryAsync = ref.watch(diaryEntriesProvider);
    return Scaffold(
      body: diaryAsync.when(
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('尚無日記'))
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
                    subtitle: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(dt)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (entry.checkInRecordId != null)
                          const Icon(Icons.check_circle_outline, size: 16),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _editDiary(context, ref, entry),
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
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const DiaryEditPage(),
        )),
        child: const Icon(Icons.edit),
      ),
    );
  }

  void _editDiary(BuildContext context, WidgetRef ref, DiaryEntry entry) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DiaryEditPage(entry: entry),
    ));
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
            ? const Center(child: Text('尚無提醒'))
            : ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (_, i) => Dismissible(
                  key: ValueKey(reminders[i].id),
                  direction: DismissDirection.endToStart,
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
      builder: (ctx) => const _AddReminderSheet(),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.parse(reminder.dateTime);
    return ListTile(
      title: Text(reminder.title, style: TextStyle(
        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
      )),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(DateFormat('M/d HH:mm', 'zh-TW').format(dt)),
          if (reminder.isRepeating) ...[
            Text('重複：每週 ${reminder.repeatWeekdays!.split(',').map((s) => ['一','二','三','四','五','六','日'][int.parse(s)]).join('、')}',
              style: const TextStyle(fontSize: 12)),
            if (reminder.repeatEndDate != null)
              Text('至 ${reminder.repeatEndDate}', style: const TextStyle(fontSize: 12))
            else
              const Text('至永遠', style: TextStyle(fontSize: 12)),
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
            onPressed: () => ref.read(reminderNotifierProvider).deleteReminder(reminder.id),
          ),
        ],
      ),
    );
  }

  void _editReminder(BuildContext context, WidgetRef ref, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AddReminderSheet(editReminder: reminder),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  final Reminder? editReminder;
  const _AddReminderSheet({this.editReminder});

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleController = TextEditingController();
  late DateTime _dateTime;
  final _selectedWeekdays = <int>{};
  DateTime? _repeatEndDate;
  bool _isForever = true;
  int? _selectedCategoryId;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final edit = widget.editReminder;
    if (edit != null) {
      _titleController.text = edit.title;
      _dateTime = DateTime.parse(edit.dateTime);
      if (edit.repeatWeekdays != null) {
        _selectedWeekdays.addAll(edit.repeatWeekdays!.split(',').map(int.parse));
      }
      if (edit.repeatEndDate != null) {
        _repeatEndDate = DateTime.parse(edit.repeatEndDate!);
        _isForever = false;
      }
      _selectedCategoryId = edit.categoryId;
    } else {
      _dateTime = DateTime.now().add(const Duration(hours: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.editReminder != null ? '編輯提醒' : '新增提醒',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(_dateTime)),
            leading: const Icon(Icons.access_time),
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _dateTime,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dt != null && context.mounted) {
                final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dateTime));
                if (tm != null) {
                  setState(() => _dateTime = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                }
              }
            },
          ),
          const SizedBox(height: 8),
          Text('重複：', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: List.generate(7, (i) => FilterChip(
              label: Text(_weekdayLabels[i]),
              selected: _selectedWeekdays.contains(i),
              onSelected: (v) {
                setState(() {
                  if (v) { _selectedWeekdays.add(i); } else { _selectedWeekdays.remove(i); }
                });
              },
            )),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('結束日期：'),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isForever = !_isForever;
                      if (!_isForever && _repeatEndDate == null) {
                        _repeatEndDate = _dateTime.add(const Duration(days: 30));
                      }
                    });
                  },
                  child: Text(_isForever ? '永遠' : DateFormat('yyyy/M/d', 'zh-TW').format(_repeatEndDate!)),
                ),
              ),
              if (!_isForever)
                IconButton(
                  icon: const Icon(Icons.calendar_today, size: 20),
                  onPressed: () async {
                    final dt = await showDatePicker(
                      context: context,
                      initialDate: _repeatEndDate ?? _dateTime.add(const Duration(days: 30)),
                      firstDate: _dateTime,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (dt != null) setState(() => _repeatEndDate = dt);
                  },
                ),
            ],
          ),
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: '綁定打卡項目（可選）'),
              items: [
                const DropdownMenuItem(value: null, child: Text('不綁定')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))),
              ],
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _titleController.text.trim().isEmpty ? null : () {
              final db = ref.read(databaseProvider);
              final weekdaysStr = _selectedWeekdays.isNotEmpty ? _selectedWeekdays.join(',') : null;
              final companion = RemindersCompanion(
                title: Value(_titleController.text.trim()),
                reminderDateTime: Value(_dateTime.toIso8601String()),
                repeatWeekdays: weekdaysStr != null ? Value(weekdaysStr) : const Value.absent(),
                repeatEndDate: _isForever || _repeatEndDate == null
                    ? const Value.absent()
                    : Value(DateFormat('yyyy-MM-dd').format(_repeatEndDate!)),
                categoryId: _selectedCategoryId != null ? Value(_selectedCategoryId!) : const Value.absent(),
              );
              if (widget.editReminder != null) {
                (db.update(db.reminders)
                  ..where((t) => t.id.equals(widget.editReminder!.id)))
                  .write(companion);
              } else {
                db.into(db.reminders).insert(companion);
              }
              ref.invalidate(remindersProvider);
              Navigator.pop(context);
            },
            child: Text(widget.editReminder != null ? '儲存' : '新增'),
          ),
          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }
}
