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
import '../widgets/week_calendar.dart';
import '../widgets/add_entry_sheet.dart';
import '../providers/diary_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';

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
          showModalBottomSheet(
            context: context,
            builder: (_) => AddEntrySheet(selectedDate: _selectedDate, initialTab: _tabController.index),
          );
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
                isCompleted: existing?.isCompleted ?? false,
                note: existing?.note,
                onToggle: (value) => _toggleCheckIn(cat.id, dateStr, value ?? false, existing),
                onAddNote: () => _showNoteDialog(cat.id, dateStr, existing),
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
          children: dayEntries.map((e) => ListTile(
            title: Text(e.title ?? e.content.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(e.content.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
          )).toList(),
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
              leading: Icon(r.isCompleted ? Icons.check_circle : Icons.notifications_outlined,
                color: r.isCompleted ? Colors.green : null),
              title: Text(r.title),
              subtitle: Text(DateFormat('HH:mm', 'zh-TW').format(dt)),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _expanded
                    ? DateFormat('yyyy 年 M 月', 'zh-TW').format(_selectedDate)
                    : DateFormat('M 月 d 日', 'zh-TW').format(_selectedDate),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: Icon(_expanded ? Icons.unfold_less : Icons.unfold_more),
              onPressed: () => setState(() => _expanded = !_expanded),
            ),
          ],
        ),
        if (_expanded)
          TableCalendar(
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
          )
        else
          WeekCalendar(
            selectedDate: _selectedDate,
            markedDates: markedDates,
            onDateSelected: (day) => setState(() => _selectedDate = day),
          ),
      ],
    );
  }

  Future<void> _toggleCheckIn(int categoryId, String dateStr, bool completed, dynamic existing) async {
    final db = ref.read(databaseProvider);
    if (completed) {
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(isCompleted: Value(true)));
      } else {
        await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: categoryId,
          date: dateStr,
          isCompleted: Value(true),
        ));
      }
    } else {
      if (existing != null) {
        await (db.delete(db.checkInRecords)..where((t) => t.id.equals(existing.id))).go();
      }
    }
    ref.invalidate(checkInRecordsForDateProvider(dateStr));
    ref.invalidate(checkInRecordDatesProvider);
  }

  Future<void> _showNoteDialog(int categoryId, String dateStr, dynamic existing) async {
    final note = await showDialog<String>(context: context, builder: (_) => CheckInNoteDialog(initialNote: existing?.note));
    if (note != null) {
      final db = ref.read(databaseProvider);
      int? recordId;
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(note: Value(note)));
        recordId = existing.id;
      } else {
        recordId = await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: categoryId,
          date: dateStr,
          note: Value(note),
        ));
      }
      await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
        date: '$dateStr ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00',
        content: note,
        checkInRecordId: Value(recordId),
      ));
      ref.invalidate(checkInRecordsForDateProvider(dateStr));
      ref.invalidate(checkInRecordDatesProvider);
      ref.invalidate(diaryEntriesProvider);
    }
  }
}
