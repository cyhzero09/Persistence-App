import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/diary_provider.dart';
import '../notification_service.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';

const _emojis = [
  '🏃','📚','💧','🧘','💪','🎵','✍','🍎','☕','🎮','📝','🛌','🎯','🌈',
  '💻','📱','🎨','🎬','🎧','🏋','🚴','🏊','🥗','🧠','💊','🧹','🎁','💡',
];

/// 「新增打卡项目」底部弹窗，样式与提醒弹窗一致。
class AddCategorySheet extends ConsumerStatefulWidget {
  final DateTime? selectedDate;
  const AddCategorySheet({super.key, this.selectedDate});

  @override
  ConsumerState<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<AddCategorySheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _emoji = '📌';
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  final _weekdays = <int>{};
  bool _addReminder = false;
  TimeOfDay? _reminderTime;
  bool _emojiExpanded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.addCheckInItem, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(labelText: l10n.name, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n.descriptionOptional,
                border: const OutlineInputBorder(),
                hintText: l10n.descriptionHint,
              ),
            ),
            const SizedBox(height: 12),
            Text(l10n.chooseIcon(_emoji), style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ..._emojis.take(_emojiExpanded ? _emojis.length : 8).map((e) => GestureDetector(
                  onTap: () => setState(() => _emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _emoji == e ? cs.primaryContainer : null,
                      border: Border.all(
                        color: _emoji == e ? cs.primary : cs.outline,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                )),
                if (!_emojiExpanded)
                  _emojiToggle(Icons.unfold_more, '+${_emojis.length - 8}', cs)
                else
                  _emojiToggle(Icons.unfold_less, '', cs),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_startTime != null
                  ? '⏰ ${l10n.startTimeValue(_startTime!.format(context))}'
                  : '⏰ ${l10n.startTimeLabel}'),
              trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
                if (t != null) setState(() => _startTime = t);
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_endTime != null
                  ? '⏰ ${l10n.endTimeValue(_endTime!.format(context))}'
                  : '⏰ ${l10n.endTimeLabel}'),
              trailing: IconButton(icon: const Icon(Icons.access_time), onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _endTime ?? TimeOfDay.now());
                if (t != null) setState(() => _endTime = t);
              }),
            ),
            const SizedBox(height: 8),
            Text(l10n.repeatDays,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: List.generate(7, (i) => FilterChip(
                label: Text(chipWeekdayLabels(context)[i]),
                selected: _weekdays.contains(i),
                onSelected: (v) {
                  setState(() { if (v) { _weekdays.add(i); } else { _weekdays.remove(i); } });
                },
              )),
            ),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                Text(l10n.addReminder),
                Switch(
                  value: _addReminder,
                  onChanged: (v) => setState(() => _addReminder = v),
                ),
              ],
            ),
            if (_addReminder) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l10n.setTime),
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
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _nameController.text.trim().isEmpty ||
                      _startTime == null || _endTime == null || _weekdays.isEmpty
                  ? null
                  : _save,
              child: Text(l10n.add),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _emojiToggle(IconData icon, String label, ColorScheme cs) {
    return GestureDetector(
      onTap: () => setState(() => _emojiExpanded = !_emojiExpanded),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: label.isNotEmpty
            ? Text(label, style: TextStyle(fontSize: 14, color: cs.primary))
            : Icon(icon, size: 20, color: cs.primary),
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final weekdaysStr = _weekdays.join(',');
    final catId = await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
      name: _nameController.text.trim(),
      emoji: _emoji,
      description: _descController.text.trim().isNotEmpty ? Value(_descController.text.trim()) : const Value.absent(),
      startTime: Value('${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}'),
      endTime: Value('${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}'),
      repeatWeekdays: Value(weekdaysStr),
    ));
    if (_addReminder && _reminderTime != null) {
      final base = widget.selectedDate ?? DateTime.now();
      final reminderDt = DateTime(
          base.year, base.month, base.day,
          _reminderTime!.hour, _reminderTime!.minute);
      final id = await db.into(db.reminders).insert(RemindersCompanion.insert(
        title: _nameController.text.trim(),
        reminderDateTime: reminderDt.toIso8601String(),
        repeatWeekdays: Value(weekdaysStr),
        categoryId: Value(catId),
      ));
      final l10n = AppLocalizations.of(context);
      // 通知调度在后台进行，不阻塞界面响应
      unawaited(NotificationService().scheduleReminder(
        id: id,
        title: _nameController.text.trim(),
        body: l10n.reminderNotification(_nameController.text.trim()),
        scheduledDate: reminderDt,
        repeatWeekdays: weekdaysStr,
      ));
    }
    ref.invalidate(categoriesProvider);
    ref.invalidate(remindersProvider);
    if (context.mounted) Navigator.pop(context);
  }
}

/// 「新增日记」底部弹窗，样式与提醒弹窗一致。
class AddDiarySheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  const AddDiarySheet({super.key, this.initialDate});

  @override
  ConsumerState<AddDiarySheet> createState() => _AddDiarySheetState();
}

class _AddDiarySheetState extends ConsumerState<AddDiarySheet> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late DateTime _diaryDate;
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    _diaryDate = widget.initialDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateStr = DateFormat('yyyy/M/d', intlLocaleOf(context)).format(_diaryDate);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.writeDiary, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: TextEditingController(text: dateStr),
              readOnly: true,
              decoration: InputDecoration(
                labelText: l10n.dateRequired,
                border: const OutlineInputBorder(),
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _diaryDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (dt != null) setState(() => _diaryDate = dt);
              },
              onChanged: (_) {},
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: InputDecoration(labelText: l10n.titleOptional, border: const OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.contentLabel,
                border: const OutlineInputBorder(),
                hintText: l10n.diaryContentHint,
              ),
              onChanged: (v) => setState(() => _hasContent = v.trim().isNotEmpty),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _hasContent ? _save : null,
              child: Text(l10n.addDiary),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_diaryDate);
    final now = DateTime.now();
    final dateTimeStr = '$dateStr ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';
    await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
      date: dateTimeStr,
      title: _titleController.text.trim().isNotEmpty ? Value(_titleController.text.trim()) : const Value.absent(),
      content: _contentController.text.trim(),
    ));
    ref.invalidate(diaryEntriesProvider);
    if (context.mounted) Navigator.pop(context);
  }
}