import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder;
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/diary_provider.dart';
import '../providers/database_provider.dart';
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
  DateTime _reminderDate = DateTime.now().add(const Duration(hours: 1));
  final _selectedWeekdays = <int>{};
  DateTime? _repeatEndDate;
  bool _isForever = true;
  int? _reminderCategoryId;

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

  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(_reminderDate)),
            leading: const Icon(Icons.access_time),
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _reminderDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dt != null && context.mounted) {
                final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_reminderDate));
                if (tm != null) {
                  setState(() => _reminderDate = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('結束日期：'),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _isForever = !_isForever;
                      if (!_isForever && _repeatEndDate == null) {
                        _repeatEndDate = widget.selectedDate.add(const Duration(days: 30));
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
                      initialDate: _repeatEndDate ?? widget.selectedDate.add(const Duration(days: 30)),
                      firstDate: widget.selectedDate,
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                    );
                    if (dt != null) setState(() => _repeatEndDate = dt);
                  },
                ),
            ],
          ),
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<int?>(
              value: _reminderCategoryId,
              decoration: const InputDecoration(labelText: '綁定打卡項目（可選）'),
              items: [
                const DropdownMenuItem(value: null, child: Text('不綁定')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))),
              ],
              onChanged: (v) => setState(() => _reminderCategoryId = v),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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
    final weekdaysStr = _selectedWeekdays.isNotEmpty ? _selectedWeekdays.join(',') : null;
    await db.into(db.reminders).insert(RemindersCompanion.insert(
      title: _reminderTitleController.text.trim(),
      reminderDateTime: _reminderDate.toIso8601String(),
      repeatWeekdays: weekdaysStr != null ? Value(weekdaysStr) : const Value.absent(),
      repeatEndDate: _isForever || _repeatEndDate == null
          ? const Value.absent()
          : Value(DateFormat('yyyy-MM-dd').format(_repeatEndDate!)),
      categoryId: _reminderCategoryId != null ? Value(_reminderCategoryId!) : const Value.absent(),
    ));
    ref.invalidate(remindersProvider);
    if (context.mounted) Navigator.pop(context);
  }
}
