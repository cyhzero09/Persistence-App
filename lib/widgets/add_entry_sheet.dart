import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder;
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/database_provider.dart';
import '../notification_service.dart';
import '../models/check_in_category.dart';
class AddEntrySheet extends ConsumerStatefulWidget {
  final DateTime selectedDate;
  final int initialTab;

  const AddEntrySheet({super.key, required this.selectedDate, this.initialTab = 0});

  @override
  ConsumerState<AddEntrySheet> createState() => _AddEntrySheetState();
}

class _AddEntrySheetState extends ConsumerState<AddEntrySheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _noteController = TextEditingController();
  int? _selectedCategoryId;

  final _diaryDateController = TextEditingController();
  final _diaryTitleController = TextEditingController();
  final _diaryContentController = TextEditingController();
  DateTime _diaryDate = DateTime.now();
  bool _diaryHasContent = false;

  final _reminderTitleController = TextEditingController();
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
    _diaryDate = widget.selectedDate;
    _diaryDateController.text = DateFormat('yyyy/M/d', 'zh-TW').format(_diaryDate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noteController.dispose();
    _diaryDateController.dispose();
    _diaryTitleController.dispose();
    _diaryContentController.dispose();
    _reminderTitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.selectedDate);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '打卡'),
              Tab(text: '日記'),
              Tab(text: '提醒'),
            ],
          ),
          SizedBox(
            height: 380,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCheckInTab(categoriesAsync, dateStr),
                _buildDiaryTab(),
                _buildReminderTab(categoriesAsync),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInTab(AsyncValue<List<CheckInCategory>> categoriesAsync, String dateStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('新增打卡 - ${DateFormat('M/d', 'zh-TW').format(widget.selectedDate)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<int>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: '打卡項目', border: OutlineInputBorder()),
              items: cats.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text('${c.emoji} ${c.name}'),
              )).toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('$e'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: '備註', border: OutlineInputBorder(), hintText: '今天狀態如何？'),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _selectedCategoryId == null ? null : () => _saveCheckIn(dateStr),
            child: const Text('新增打卡'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('新增日記', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _diaryDateController,
            decoration: const InputDecoration(labelText: '日期 *', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
            readOnly: true,
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _diaryDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dt != null) {
                setState(() {
                  _diaryDate = dt;
                  _diaryDateController.text = DateFormat('yyyy/M/d', 'zh-TW').format(dt);
                });
              }
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diaryTitleController,
            decoration: const InputDecoration(labelText: '標題（可選）', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _diaryContentController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: '內容', border: OutlineInputBorder(), hintText: '今天發生了什麼事...'),
            onChanged: (v) => setState(() => _diaryHasContent = v.trim().isNotEmpty),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _diaryHasContent ? () => _saveDiary() : null,
            child: const Text('新增日記'),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderTab(AsyncValue<List<CheckInCategory>> categoriesAsync) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('新增提醒', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _reminderTitleController,
            decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _reminderTitleController.text.trim().isEmpty ? null : () => _saveReminder(),
            child: const Text('新增提醒'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCheckIn(String dateStr) async {
    final db = ref.read(databaseProvider);
    await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
      categoryId: _selectedCategoryId!,
      date: dateStr,
      note: _noteController.text.trim().isNotEmpty ? Value(_noteController.text.trim()) : const Value.absent(),
    ));
    ref.invalidate(checkInRecordsForDateProvider(dateStr));
    ref.invalidate(checkInRecordDatesProvider);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _saveDiary() async {
    final db = ref.read(databaseProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_diaryDate);
    final now = DateTime.now();
    final dateTimeStr = '$dateStr ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
    await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
      date: dateTimeStr,
      title: _diaryTitleController.text.trim().isNotEmpty ? Value(_diaryTitleController.text.trim()) : const Value.absent(),
      content: _diaryContentController.text.trim(),
    ));
    ref.invalidate(diaryEntriesProvider);
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _saveReminder() async {
    final db = ref.read(databaseProvider);
    if (_reminderTime == null) return;
    final reminderDt = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day,
        _reminderTime!.hour, _reminderTime!.minute);
    final id = await db.into(db.reminders).insert(RemindersCompanion.insert(
      title: _reminderTitleController.text.trim(),
      reminderDateTime: reminderDt.toIso8601String(),
    ));
    if (reminderDt.isAfter(DateTime.now())) {
      await NotificationService().scheduleReminder(
        id: id,
        title: _reminderTitleController.text.trim(),
        body: '提醒：${_reminderTitleController.text.trim()}',
        scheduledDate: reminderDt,
      );
    }
    ref.invalidate(remindersProvider);
    if (context.mounted) Navigator.pop(context);
  }
}
