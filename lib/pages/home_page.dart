import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../database/database.dart' hide CheckInCategory, CheckInRecord, DiaryEntry, Reminder;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../widgets/check_in_dialog.dart';
import '../widgets/check_in_tile.dart';
import '../widgets/add_entry_sheet.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../notification_service.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';
import 'diary_detail_page.dart';
import 'diary_edit_page.dart';
import 'category_detail_page.dart';

const _emojis = [
  '🏃','📚','💧','🧘','💪','🎵','✍','🍎','☕','🎮','📝','🛌','🎯','🌈',
  '💻','📱','🎨','🎬','🎧','🏋','🚴','🏊','🥗','🧠','💊','🧹','🎁','💡',
];

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with TickerProviderStateMixin {
  late DateTime _selectedDate;
  bool _expanded = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Set<DateTime> _parseMarkedDates(List<String> dateStrings) {
    return dateStrings.map((s) {
      final parts = s.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final recordsAsync = ref.watch(checkInRecordsForDateProvider(dateStr));
    final datesAsync = ref.watch(checkInRecordDatesProvider);
    final diaryAsync = ref.watch(diaryEntriesProvider);
    final remindersAsync = ref.watch(remindersProvider);

    final diaryDatesAsync = ref.watch(diaryDateStringsProvider);
    final reminderDatesAsync = ref.watch(reminderDateStringsProvider);

    final activeDatesAsync = switch (_tabController.index) {
      1 => diaryDatesAsync,
      2 => reminderDatesAsync,
      _ => datesAsync,
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('M 月 d 日 EEEE', 'zh-TW').format(_selectedDate)),
        actions: [
          IconButton(
            icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more),
            onPressed: () => setState(() => _expanded = !_expanded),
          ),
        ],
      ),
      body: Column(
        children: [
          activeDatesAsync.when(
            data: (dates) => _buildCalendar(dates),
            loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('$e')),
          ),
          const Divider(height: 1),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '打卡'),
              Tab(text: '日記'),
              Tab(text: '提醒'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCheckInTab(categoriesAsync, recordsAsync, dateStr),
                _buildDiaryTab(diaryAsync, dateStr),
                _buildReminderTab(remindersAsync, dateStr),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          switch (_tabController.index) {
            case 0: _showAddCategoryDialog();
            case 1: Navigator.push(context, MaterialPageRoute(builder: (_) => const DiaryEditPage()));
            case 2: showModalBottomSheet(context: context, builder: (_) => AddEntrySheet(selectedDate: _selectedDate, initialTab: 2));
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCheckInTab(
    AsyncValue<List<CheckInCategory>> categoriesAsync,
    AsyncValue<List<CheckInRecord>> recordsAsync,
    String dateStr,
  ) {
    return categoriesAsync.when(
      data: (categories) => recordsAsync.when(
        data: (records) {
          if (categories.isEmpty) {
            return const Center(child: Text('請先在「內容」頁新增打卡項目'));
          }
          return ListView(
            children: categories.map((cat) {
              final record = records.where((r) => r.categoryId == cat.id).toList();
              final existing = record.isNotEmpty ? record.first : null;
              return CheckInTile(
                category: cat,
                record: existing,
                onToggle: (value) => _toggleCheckIn(cat.id, dateStr, value ?? false, existing),
                onAddNote: () => _showNoteDialog(cat.id, dateStr, existing),
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => CategoryDetailPage(category: cat),
                )),
                onEdit: () => _showEditCategoryDialog(cat),
                onDelete: () => _deleteCategory(cat.id),
              );
            }).toList(),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _buildDiaryTab(AsyncValue<List<DiaryEntry>> diaryAsync, String dateStr) {
    return diaryAsync.when(
      data: (entries) {
        final dayEntries = entries.where((e) => e.date.startsWith(dateStr)).toList();
        if (dayEntries.isEmpty) return const Center(child: Text('此日無日記'));
        return ListView(
          children: dayEntries.map((e) {
            final dt = DateTime.parse(e.date);
            return ListTile(
              title: Text(e.title ?? e.content.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${DateFormat('HH:mm', 'zh-TW').format(dt)}  ${e.content.split('\n').first}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _editDiary(e),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteDiary(e.id),
                  ),
                ],
              ),
              onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DiaryDetailPage(entry: e),
              )),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _buildReminderTab(AsyncValue<List<Reminder>> remindersAsync, String dateStr) {
    return remindersAsync.when(
      data: (reminders) {
        final dayReminders = reminders.where((r) {
          final dt = DateTime.parse(r.dateTime);
          return DateFormat('yyyy-MM-dd').format(dt) == dateStr;
        }).toList();
        if (dayReminders.isEmpty) return const Center(child: Text('此日無提醒'));
        return ListView(
          children: dayReminders.map((r) {
            final dt = DateTime.parse(r.dateTime);
            return ListTile(
              leading: Checkbox(
                value: r.isCompleted,
                onChanged: (v) => _toggleReminder(r.id, v ?? false),
              ),
              title: Text(r.title, style: TextStyle(
                decoration: r.isCompleted ? TextDecoration.lineThrough : null,
              )),
              subtitle: Text(DateFormat('HH:mm', 'zh-TW').format(dt)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => _editReminder(context, r),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _deleteReminder(r.id),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e')),
    );
  }

  Widget _buildCalendar(List<String> dates) {
    final markedDates = _parseMarkedDates(dates);
    if (_expanded) {
      return TableCalendar(
        firstDay: DateTime(2024),
        lastDay: DateTime.now().add(const Duration(days: 365)),
        focusedDay: _selectedDate,
        selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
        onDaySelected: (selectedDay, focusedDay) => setState(() => _selectedDate = selectedDay),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondary,
            shape: BoxShape.circle,
          ),
        ),
        eventLoader: (day) {
          final dateOnly = DateTime(day.year, day.month, day.day);
          return markedDates.contains(dateOnly) ? [true] : [];
        },
        locale: 'zh-TW',
        headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      );
    }
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final sunday = _sundayOf(today);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: List.generate(7, (i) => Expanded(
              child: Center(
                child: Text(['日','一','二','三','四','五','六'][i],
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            )),
          ),
        ),
        _buildWeekRow(sunday.subtract(const Duration(days: 7)), todayDate, markedDates),
        const SizedBox(height: 2),
        _buildWeekRow(sunday, todayDate, markedDates),
        const SizedBox(height: 2),
        _buildWeekRow(sunday.add(const Duration(days: 7)), todayDate, markedDates),
      ],
    );
  }

  DateTime _sundayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday % 7));
  }

  Widget _buildWeekRow(DateTime weekStart, DateTime todayDate, Set<DateTime> markedDates) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: days.map((day) {
          final dayDate = DateTime(day.year, day.month, day.day);
          final isSelected = dayDate == DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
          final isToday = dayDate == todayDate;
          final hasMark = markedDates.contains(dayDate);
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedDate = day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : (isToday ? Theme.of(context).colorScheme.primaryContainer : null),
                  shape: BoxShape.circle,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (hasMark)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 7),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _toggleCheckIn(int categoryId, String dateStr, bool completed, dynamic existing) async {
    final db = ref.read(databaseProvider);
    if (completed) {
      final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(
            isCompleted: Value(true),
            completedAt: Value(now),
          ));
      } else {
        await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: categoryId,
          date: dateStr,
          isCompleted: Value(true),
          completedAt: Value(now),
        ));
      }
    } else {
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(
            isCompleted: Value(false),
          ));
      }
    }
    ref.invalidate(checkInRecordsForDateProvider(dateStr));
    ref.invalidate(checkInRecordDatesProvider);
  }

  Future<void> _showNoteDialog(int categoryId, String dateStr, dynamic existing) async {
    final note = await showDialog<String>(context: context, builder: (_) => CheckInNoteDialog(initialNote: existing?.note));
    if (note != null) {
      final db = ref.read(databaseProvider);
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(note: Value(note)));
      } else {
        await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: categoryId,
          date: dateStr,
          note: Value(note),
          completedAt: Value(DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())),
        ));
      }
      ref.invalidate(checkInRecordsForDateProvider(dateStr));
      ref.invalidate(checkInRecordDatesProvider);
    }
  }

  Future<void> _deleteCategory(int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showAddCategoryDialog() {
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
                  final reminderDt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day,
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

  void _showEditCategoryDialog(CheckInCategory category) {
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

  void _editDiary(DiaryEntry entry) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DiaryEditPage(entry: entry),
    ));
  }

  Future<void> _deleteDiary(int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.diaryEntries)..where((t) => t.id.equals(id))).go();
    ref.invalidate(diaryEntriesProvider);
  }

  Future<void> _toggleReminder(int id, bool completed) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.reminders)..where((t) => t.id.equals(id))).write(RemindersCompanion(
      isCompleted: Value(completed),
    ));
    if (completed) {
      await NotificationService().cancelReminder(id);
    }
    ref.invalidate(remindersProvider);
  }

  void _editReminder(BuildContext context, Reminder reminder) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        content: _EditReminderSheet(reminder: reminder),
      ),
    );
  }

  Future<void> _deleteReminder(int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    await NotificationService().cancelReminder(id);
    ref.invalidate(remindersProvider);
  }
}

class _EditReminderSheet extends ConsumerStatefulWidget {
  final Reminder reminder;
  const _EditReminderSheet({required this.reminder});

  @override
  ConsumerState<_EditReminderSheet> createState() => _EditReminderSheetState();
}

class _EditReminderSheetState extends ConsumerState<_EditReminderSheet> {
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
    final edit = widget.reminder;
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
          const Text('編輯提醒',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              await (db.update(db.reminders)
                ..where((t) => t.id.equals(widget.reminder.id)))
                .write(companion);
              await NotificationService().cancelReminder(widget.reminder.id);
              if (reminderDt.isAfter(DateTime.now())) {
                await NotificationService().scheduleReminder(
                  id: widget.reminder.id,
                  title: _titleController.text.trim(),
                  body: '提醒：${_titleController.text.trim()}',
                  scheduledDate: reminderDt,
                );
              }
              ref.invalidate(remindersProvider);
              if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
            },
            child: const Text('儲存'),
          ),
          const SizedBox(height: 16),
        ],
      ),
      ),
    );
  }
}
