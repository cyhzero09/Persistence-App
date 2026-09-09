import 'package:drift/drift.dart' hide Column;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/week_calendar.dart';
import '../database/database.dart' hide CheckInCategory, CheckInRecord, DiaryEntry, Reminder;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../widgets/check_in_dialog.dart';
import '../widgets/check_in_tile.dart';
import '../widgets/add_sheets.dart';
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
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';
import '../utils/confirm_delete.dart';

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
    final l10n = AppLocalizations.of(context);
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
        title: Text(homeDateTitle(context, _selectedDate)),
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
            data: (dates) => WeekCalendar(
              selectedDate: _selectedDate,
              markedDates: _parseMarkedDates(dates),
              showFullMonth: _expanded,
              onDateSelected: (d) => setState(() => _selectedDate = d),
            ),
            loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Center(child: Text('$e')),
          ),
          const Divider(height: 1),
          TabBar(
            controller: _tabController,
            tabs: [
              Tab(text: l10n.tabCheckIn),
              Tab(text: l10n.tabDiary),
              Tab(text: l10n.tabReminder),
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
            case 0: showModalBottomSheet(context: context, builder: (_) => AddCategorySheet(selectedDate: _selectedDate));
            case 1: showModalBottomSheet(context: context, builder: (_) => AddDiarySheet(initialDate: _selectedDate));
            case 2: showModalBottomSheet(context: context, builder: (_) => const AddReminderSheet());
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
            return Center(child: Text(AppLocalizations.of(context).homeEmptyCheckIn));
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
        if (dayEntries.isEmpty) return Center(child: Text(AppLocalizations.of(context).homeNoDiary));
        return ListView(
          children: dayEntries.map((e) {
            final dt = DateTime.parse(e.date);
            return ListTile(
              title: Text(e.title ?? e.content.split('\n').first, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${DateFormat('HH:mm', intlLocaleOf(context)).format(dt)}  ${e.content.split('\n').first}',
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
        if (dayReminders.isEmpty) return Center(child: Text(AppLocalizations.of(context).homeNoReminder));
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
              subtitle: Text(DateFormat('HH:mm', intlLocaleOf(context)).format(dt)),
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
        // 取消打卡：删除该条记录，避免残留无效记录
        await (db.delete(db.checkInRecords)..where((t) => t.id.equals(existing.id))).go();
      }
    }
    ref.invalidate(checkInRecordsForDateProvider(dateStr));
    ref.invalidate(checkInRecordsForCategoryProvider(categoryId));
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
      ref.invalidate(checkInRecordsForCategoryProvider(categoryId));
      ref.invalidate(checkInRecordDatesProvider);
    }
  }

  Future<void> _deleteCategory(int id) async {
    if (!await confirmDelete(context)) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordsForCategoryProvider(id));
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showEditCategoryDialog(CheckInCategory category) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AddCategorySheet(category: category),
    );
  }

  void _editDiary(DiaryEntry entry) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AddDiarySheet(entry: entry),
    );
  }

  Future<void> _deleteDiary(int id) async {
    if (!await confirmDelete(context)) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.diaryEntries)..where((t) => t.id.equals(id))).go();
    ref.invalidate(diaryEntriesProvider);
  }

  Future<void> _toggleReminder(int id, bool completed) async {
    final db = ref.read(databaseProvider);
    await (db.update(db.reminders)..where((t) => t.id.equals(id))).write(RemindersCompanion(
      isCompleted: Value(completed),
    ));
    // 先刷新 UI，通知操作后台执行，避免卡顿
    ref.invalidate(remindersProvider);
    try {
      if (completed) {
        await NotificationService().cancelReminder(id);
      } else {
        final rows = await (db.select(db.reminders)..where((t) => t.id.equals(id))).get();
        if (rows.isNotEmpty) {
          final r = rows.first;
          final dt = DateTime.parse(r.reminderDateTime);
          // 重复提醒即使当天时间已过，scheduleReminder 也会调度下一次触发
          await NotificationService().scheduleReminder(
            id: r.id,
            title: r.title,
            body: r.title,
            scheduledDate: dt,
            repeatWeekdays: r.repeatWeekdays,
          );
        }
      }
    } catch (_) {
      // 通知调度失败不应影响提醒状态的 UI 刷新
    }
  }

  void _editReminder(BuildContext context, Reminder reminder) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AddReminderSheet(editReminder: reminder),
    );
  }

  Future<void> _deleteReminder(int id) async {
    if (!await confirmDelete(context)) return;
    final db = ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    // 先刷新 UI，取消通知后台执行，避免卡顿
    ref.invalidate(remindersProvider);
    unawaited(NotificationService().cancelReminder(id));
  }
}
