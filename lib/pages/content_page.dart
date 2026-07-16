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
    TimeOfDay? catStartTime;
    TimeOfDay? catEndTime;
    final catWeekdays = <int>{};
    bool addReminder = false;
    TimeOfDay? reminderTime;

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
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(catStartTime != null ? '⏰ 開始 ${catStartTime!.format(context)}' : '⏰ 開始時間'),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: catStartTime ?? TimeOfDay.now());
                    if (t != null) setDialogState(() => catStartTime = t);
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(catEndTime != null ? '⏰ 結束 ${catEndTime!.format(context)}' : '⏰ 結束時間'),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: catEndTime ?? TimeOfDay.now());
                    if (t != null) setDialogState(() => catEndTime = t);
                  }),
                ),
                const SizedBox(height: 8),
                Text('重複天數：', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) => FilterChip(
                    label: Text(['一','二','三','四','五','六','日'][i]),
                    selected: catWeekdays.contains(i),
                    onSelected: (v) {
                      setDialogState(() {
                        if (v) { catWeekdays.add(i); } else { catWeekdays.remove(i); }
                      });
                    },
                  )),
                ),
                const SizedBox(height: 12),
                const Divider(),
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
                  Row(
                    children: [
                      const Text('設定時間'),
                      Switch(
                        value: reminderTime != null,
                        onChanged: (v) => setDialogState(() {
                          reminderTime = v ? TimeOfDay.now() : null;
                        }),
                      ),
                    ],
                  ),
                  if (reminderTime != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('⏰ ${reminderTime!.format(context)}'),
                      leading: const Icon(Icons.access_time),
                      onTap: () async {
                        final tm = await showTimePicker(context: context, initialTime: reminderTime!);
                        if (tm != null) setDialogState(() => reminderTime = tm);
                      },
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty || catStartTime == null || catEndTime == null || catWeekdays.isEmpty
                  ? null : () async {
                final db = ref.read(databaseProvider);
                final weekdaysStr = catWeekdays.join(',');
                final catId = await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
                  name: nameController.text.trim(),
                  emoji: emoji,
                  description: descController.text.trim().isNotEmpty ? Value(descController.text.trim()) : const Value.absent(),
                  startTime: Value('${catStartTime!.hour.toString().padLeft(2, '0')}:${catStartTime!.minute.toString().padLeft(2, '0')}'),
                  endTime: Value('${catEndTime!.hour.toString().padLeft(2, '0')}:${catEndTime!.minute.toString().padLeft(2, '0')}'),
                  repeatWeekdays: Value(weekdaysStr),
                ));
                if (addReminder && reminderTime != null) {
                  final reminderDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day,
                      reminderTime!.hour, reminderTime!.minute);
                  final id = await db.into(db.reminders).insert(RemindersCompanion.insert(
                    title: nameController.text.trim(),
                    reminderDateTime: reminderDt.toIso8601String(),
                    repeatWeekdays: Value(weekdaysStr),
                    categoryId: Value(catId),
                  ));
                  if (reminderDt.isAfter(DateTime.now())) {
                    await NotificationService().scheduleReminder(
                      id: id,
                      title: nameController.text.trim(),
                      body: '提醒：${nameController.text.trim()}',
                      scheduledDate: reminderDt,
                    );
                  }
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
    TimeOfDay? editStartTime = category.startTime != null
        ? TimeOfDay(
            hour: int.parse(category.startTime!.split(':')[0]),
            minute: int.parse(category.startTime!.split(':')[1]),
          )
        : null;
    TimeOfDay? editEndTime = category.endTime != null
        ? TimeOfDay(
            hour: int.parse(category.endTime!.split(':')[0]),
            minute: int.parse(category.endTime!.split(':')[1]),
          )
        : null;
    final editWeekdays = <int>{};
    if (category.repeatWeekdays != null) {
      editWeekdays.addAll(category.repeatWeekdays!.split(',').map(int.parse));
    }
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
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(editStartTime != null ? '⏰ 開始 ${editStartTime!.format(context)}' : '⏰ 開始時間'),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: editStartTime ?? TimeOfDay.now());
                    if (t != null) setDialogState(() => editStartTime = t);
                  }),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(editEndTime != null ? '⏰ 結束 ${editEndTime!.format(context)}' : '⏰ 結束時間'),
                  trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                    final t = await showTimePicker(context: context, initialTime: editEndTime ?? TimeOfDay.now());
                    if (t != null) setDialogState(() => editEndTime = t);
                  }),
                ),
                const SizedBox(height: 8),
                Text('重複天數：', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  children: List.generate(7, (i) => FilterChip(
                    label: Text(['一','二','三','四','五','六','日'][i]),
                    selected: editWeekdays.contains(i),
                    onSelected: (v) {
                      setDialogState(() {
                        if (v) { editWeekdays.add(i); } else { editWeekdays.remove(i); }
                      });
                    },
                  )),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty || editStartTime == null || editEndTime == null || editWeekdays.isEmpty
                  ? null : () async {
                final db = ref.read(databaseProvider);
                await (db.update(db.checkInCategories)
                  ..where((t) => t.id.equals(category.id)))
                  .write(CheckInCategoriesCompanion(
                    name: Value(nameController.text.trim()),
                    emoji: Value(emoji),
                    description: descController.text.trim().isNotEmpty ? Value(descController.text.trim()) : const Value.absent(),
                    startTime: Value('${editStartTime!.hour.toString().padLeft(2, '0')}:${editStartTime!.minute.toString().padLeft(2, '0')}'),
                    endTime: Value('${editEndTime!.hour.toString().padLeft(2, '0')}:${editEndTime!.minute.toString().padLeft(2, '0')}'),
                    repeatWeekdays: Value(editWeekdays.join(',')),
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
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteDiary(ref, entry.id),
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

  void _deleteDiary(WidgetRef ref, int id) async {
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
  late DateTime _reminderDate;
  TimeOfDay? _reminderTime;
  bool _isMultiDay = false;
  final _selectedWeekdays = <int>{};
  DateTime? _reminderEndDate;

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  @override
  void initState() {
    super.initState();
    final edit = widget.editReminder;
    if (edit != null) {
      _titleController.text = edit.title;
      final dt = DateTime.parse(edit.dateTime);
      _reminderDate = dt;
      _reminderTime = TimeOfDay.fromDateTime(dt);
      if (edit.repeatWeekdays != null) {
        _selectedWeekdays.addAll(edit.repeatWeekdays!.split(',').map(int.parse));
        _isMultiDay = _selectedWeekdays.isNotEmpty;
      }
      if (edit.repeatEndDate != null) {
        _reminderEndDate = DateTime.parse(edit.repeatEndDate!);
      }
    } else {
      _reminderDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('單天')),
              ButtonSegment(value: true, label: Text('多天')),
            ],
            selected: {_isMultiDay},
            onSelectionChanged: (v) => setState(() => _isMultiDay = v.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_isMultiDay
                ? '開始：${DateFormat('yyyy/M/d', 'zh-TW').format(_reminderDate)}'
                : DateFormat('yyyy/M/d', 'zh-TW').format(_reminderDate)),
            leading: const Icon(Icons.calendar_today),
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _reminderDate,
                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dt != null) setState(() => _reminderDate = dt);
            },
          ),
          Row(
            children: [
              const Text('設定時間'),
              Switch(
                value: _reminderTime != null,
                onChanged: (v) => setState(() => _reminderTime = v ? TimeOfDay.now() : null),
              ),
            ],
          ),
          if (_reminderTime != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('⏰ ${_reminderTime!.format(context)}'),
              leading: const Icon(Icons.access_time),
              onTap: () async {
                final tm = await showTimePicker(context: context, initialTime: _reminderTime!);
                if (tm != null) setState(() => _reminderTime = tm);
              },
            ),
          if (_isMultiDay) ...[
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
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_reminderEndDate != null
                  ? '結束：${DateFormat('yyyy/M/d', 'zh-TW').format(_reminderEndDate!)}'
                  : '結束日期（可選）'),
              trailing: _reminderEndDate != null
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _reminderEndDate = null))
                  : null,
              leading: const Icon(Icons.event),
              onTap: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _reminderEndDate ?? _reminderDate.add(const Duration(days: 30)),
                  firstDate: _reminderDate,
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (dt != null) setState(() => _reminderEndDate = dt);
              },
            ),
            const Text('提示：結束留空 = 持續有效', style: TextStyle(fontSize: 12)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _titleController.text.trim().isEmpty ? null : () async {
              final db = ref.read(databaseProvider);
              final reminderDt = _reminderTime != null
                  ? DateTime(_reminderDate.year, _reminderDate.month, _reminderDate.day, _reminderTime!.hour, _reminderTime!.minute)
                  : _reminderDate;
              final weekdaysStr = _selectedWeekdays.isNotEmpty ? _selectedWeekdays.join(',') : null;
              final companion = RemindersCompanion(
                title: Value(_titleController.text.trim()),
                reminderDateTime: Value(reminderDt.toIso8601String()),
                repeatWeekdays: weekdaysStr != null ? Value(weekdaysStr) : const Value.absent(),
                repeatEndDate: _reminderEndDate != null ? Value(DateFormat('yyyy-MM-dd').format(_reminderEndDate!)) : const Value.absent(),
              );
              if (widget.editReminder != null) {
                await (db.update(db.reminders)
                  ..where((t) => t.id.equals(widget.editReminder!.id)))
                  .write(companion);
                await NotificationService().cancelReminder(widget.editReminder!.id);
                if (reminderDt.isAfter(DateTime.now())) {
                  await NotificationService().scheduleReminder(
                    id: widget.editReminder!.id,
                    title: _titleController.text.trim(),
                    body: '提醒：${_titleController.text.trim()}',
                    scheduledDate: reminderDt,
                  );
                }
              } else {
                final id = await db.into(db.reminders).insert(companion);
                if (reminderDt.isAfter(DateTime.now())) {
                  await NotificationService().scheduleReminder(
                    id: id,
                    title: _titleController.text.trim(),
                    body: '提醒：${_titleController.text.trim()}',
                    scheduledDate: reminderDt,
                  );
                }
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
