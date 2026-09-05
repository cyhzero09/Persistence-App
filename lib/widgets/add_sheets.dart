import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, Reminder, DiaryEntry;
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/diary_provider.dart';
import '../notification_service.dart';
import '../models/check_in_category.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';

const _emojis = [
  '🏃','📚','💧','🧘','💪','🎵','✍','🍎','☕','🎮','📝','🛌','🎯','🌈',
  '💻','📱','🎨','🎬','🎧','🏋','🚴','🏊','🥗','🧠','💊','🧹','🎁','💡',
];

/// 「小时/分钟」主题色双列滚轮时间选择器（底部弹窗）。
Future<TimeOfDay?> showTimeWheelPicker(
  BuildContext context, {
  required TimeOfDay initialTime,
}) {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    builder: (_) => _TimeWheelSheet(initial: initialTime),
  );
}

class _TimeWheelSheet extends StatefulWidget {
  final TimeOfDay initial;
  const _TimeWheelSheet({required this.initial});
  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  late int _hour = widget.initial.hour;
  late int _minute = widget.initial.minute;
  static const double _itemExtent = 38;

  void _confirm() {
    Navigator.of(context).pop(TimeOfDay(hour: _hour, minute: _minute));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const double height = 180;
    final topLine = (height - _itemExtent) / 2;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NumberWheel(
                        count: 24,
                        selected: _hour,
                        color: scheme.primary,
                        dim: scheme.onSurfaceVariant,
                        onChanged: (v) => setState(() => _hour = v),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(':', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600)),
                      ),
                      _NumberWheel(
                        count: 60,
                        selected: _minute,
                        color: scheme.primary,
                        dim: scheme.onSurfaceVariant,
                        padLeft: true,
                        onChanged: (v) => setState(() => _minute = v),
                      ),
                    ],
                  ),
                  IgnorePointer(
                    child: Stack(
                      children: [
                        Positioned(
                          top: topLine, left: 0, right: 0,
                          child: Container(height: 1, color: scheme.outlineVariant),
                        ),
                        Positioned(
                          top: topLine + _itemExtent, left: 0, right: 0,
                          child: Container(height: 1, color: scheme.outlineVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _confirm, child: const Text('确定')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberWheel extends StatefulWidget {
  final int count;
  final int selected;
  final Color color;
  final Color dim;
  final bool padLeft;
  final ValueChanged<int> onChanged;
  const _NumberWheel({
    required this.count,
    required this.selected,
    required this.color,
    required this.dim,
    required this.onChanged,
    this.padLeft = false,
  });
  @override
  State<_NumberWheel> createState() => _NumberWheelState();
}

class _NumberWheelState extends State<_NumberWheel> {
  late final FixedExtentScrollController _ctrl =
      FixedExtentScrollController(initialItem: widget.selected);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      child: ListWheelScrollView(
        controller: _ctrl,
        itemExtent: 38,
        overAndUnderCenterOpacity: 0.35,
        physics: const FixedExtentScrollPhysics(),
        onSelectedItemChanged: widget.onChanged,
        children: List.generate(widget.count, (i) {
          final sel = i == widget.selected;
          final txt = widget.padLeft ? '$i'.padLeft(2, '0') : '$i';
          return Center(
            child: Text(
              txt,
              style: TextStyle(
                fontSize: sel ? 26 : 18,
                fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                color: sel ? widget.color : widget.dim,
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 「新增/编辑打卡项目」底部弹窗，样式与提醒弹窗一致。
class AddCategorySheet extends ConsumerStatefulWidget {
  final DateTime? selectedDate;
  final CheckInCategory? category;
  const AddCategorySheet({super.key, this.selectedDate, this.category});

  @override
  ConsumerState<AddCategorySheet> createState() => _AddCategorySheetState();
}

class _AddCategorySheetState extends ConsumerState<AddCategorySheet> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  String _emoji = '📌';
  DateTime? _startDate;
  DateTime? _endDate;
  final _weekdays = <int>{};
  bool _addReminder = false;
  TimeOfDay? _reminderTime;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    if (cat != null) {
      _nameController.text = cat.name;
      _descController.text = cat.description ?? '';
      _emoji = cat.emoji;
      _startDate = cat.startTime != null ? DateTime.tryParse(cat.startTime!) : null;
      _endDate = cat.endTime != null ? DateTime.tryParse(cat.endTime!) : null;
      if (cat.repeatWeekdays != null) {
        _weekdays.addAll(cat.repeatWeekdays!.split(',').map(int.parse));
      }
    }
  }

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.category != null ? l10n.editCheckInItem : l10n.addCheckInItem,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                    runSpacing: 8,
                    children: [
                      ..._emojis.take(8).map((e) => _emojiBox(e, cs)),
                      _emojiMoreButton(cs),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_startDate != null
                        ? '📅 ${l10n.startTimeValue(DateFormat('yyyy/M/d').format(_startDate!))}'
                        : '📅 ${l10n.startTimeLabel}'),
                    trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _startDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _startDate = d);
                    }),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_endDate != null
                        ? '📅 ${l10n.endTimeValue(DateFormat('yyyy/M/d').format(_endDate!))}'
                        : '📅 ${l10n.endTimeLabel}'),
                    trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _endDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d != null) setState(() => _endDate = d);
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
                          final tm = await showTimeWheelPicker(context, initialTime: _reminderTime!);
                          if (tm != null) setState(() => _reminderTime = tm);
                        },
                      ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _nameController.text.trim().isEmpty ||
                    _startDate == null || _endDate == null || _weekdays.isEmpty
                ? null
                : _save,
            child: Text(widget.category != null ? l10n.save : l10n.add),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _emojiBox(String e, ColorScheme cs) {
    return GestureDetector(
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
    );
  }

  Widget _emojiMoreButton(ColorScheme cs) {
    return GestureDetector(
      onTap: _showEmojiPicker,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: cs.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('+${_emojis.length - 8}', style: TextStyle(fontSize: 14, color: cs.primary)),
      ),
    );
  }

  Future<void> _showEmojiPicker() async {
    final cs = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('选择表情', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Flexible(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _emojis.map((e) => GestureDetector(
                    onTap: () => Navigator.pop(ctx, e),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _emoji == e ? cs.primaryContainer : null,
                        border: Border.all(color: _emoji == e ? cs.primary : cs.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 24)),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && mounted) setState(() => _emoji = selected);
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final weekdaysStr = _weekdays.join(',');
    final cat = widget.category;
    if (cat != null) {
      await (db.update(db.checkInCategories)
        ..where((t) => t.id.equals(cat.id)))
        .write(CheckInCategoriesCompanion(
          name: Value(_nameController.text.trim()),
          emoji: Value(_emoji),
          description: _descController.text.trim().isNotEmpty ? Value(_descController.text.trim()) : const Value.absent(),
          startTime: Value(DateFormat('yyyy-MM-dd').format(_startDate!)),
          endTime: Value(DateFormat('yyyy-MM-dd').format(_endDate!)),
          repeatWeekdays: Value(weekdaysStr),
        ));
      ref.invalidate(categoriesProvider);
      if (context.mounted) Navigator.pop(context);
      return;
    }
    final catId = await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
      name: _nameController.text.trim(),
      emoji: _emoji,
      description: _descController.text.trim().isNotEmpty ? Value(_descController.text.trim()) : const Value.absent(),
      startTime: Value(DateFormat('yyyy-MM-dd').format(_startDate!)),
      endTime: Value(DateFormat('yyyy-MM-dd').format(_endDate!)),
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

/// 「新增/编辑日记」底部弹窗，样式与提醒弹窗一致。
class AddDiarySheet extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final DiaryEntry? entry;
  const AddDiarySheet({super.key, this.initialDate, this.entry});

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
    final entry = widget.entry;
    if (entry != null) {
      _titleController.text = entry.title ?? '';
      _contentController.text = entry.content;
      _diaryDate = DateTime.parse(entry.date);
      _hasContent = entry.content.trim().isNotEmpty;
    } else {
      _diaryDate = widget.initialDate ?? DateTime.now();
    }
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.entry != null ? l10n.editDiary : l10n.writeDiary,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _hasContent ? _save : null,
            child: Text(widget.entry != null ? l10n.save : l10n.add),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final entry = widget.entry;
    if (entry != null) {
      final now = DateTime.now();
      final dateTimeStr = DateFormat('yyyy-MM-dd HH:mm:00').format(DateTime(
          _diaryDate.year, _diaryDate.month, _diaryDate.day,
          now.hour, now.minute));
      await (db.update(db.diaryEntries)
        ..where((t) => t.id.equals(entry.id)))
        .write(DiaryEntriesCompanion(
          date: Value(dateTimeStr),
          title: _titleController.text.trim().isNotEmpty ? Value(_titleController.text.trim()) : const Value.absent(),
          content: Value(_contentController.text.trim()),
        ));
      ref.invalidate(diaryEntriesProvider);
      if (context.mounted) Navigator.pop(context);
      return;
    }
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

/// 「新增/编辑提醒」底部弹窗（内容页与首页共用）。
class AddReminderSheet extends ConsumerStatefulWidget {
  final Reminder? editReminder;
  const AddReminderSheet({super.key, this.editReminder});

  @override
  ConsumerState<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<AddReminderSheet> {
  final _titleController = TextEditingController();
  late DateTime _reminderDate;
  TimeOfDay? _reminderTime;
  bool _isMultiDay = false;
  final _selectedWeekdays = <int>{};
  DateTime? _reminderEndDate;

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
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.editReminder != null ? l10n.editReminder : l10n.addReminder,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: l10n.title, border: const OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: false, label: Text(l10n.singleDay)),
                      ButtonSegment(value: true, label: Text(l10n.multiDay)),
                    ],
                    selected: {_isMultiDay},
                    onSelectionChanged: (v) => setState(() => _isMultiDay = v.first),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_isMultiDay
                        ? l10n.startLabel(DateFormat('yyyy/M/d', intlLocaleOf(context)).format(_reminderDate))
                        : DateFormat('yyyy/M/d', intlLocaleOf(context)).format(_reminderDate)),
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
                        final tm = await showTimeWheelPicker(context, initialTime: _reminderTime!);
                        if (tm != null) setState(() => _reminderTime = tm);
                      },
                    ),
                  if (_isMultiDay) ...[
                    const SizedBox(height: 8),
                    Text(l10n.repeat, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: List.generate(7, (i) => FilterChip(
                        label: Text(chipWeekdayLabels(context)[i]),
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
                          ? l10n.endLabel(DateFormat('yyyy/M/d', intlLocaleOf(context)).format(_reminderEndDate!))
                          : l10n.endDateOptional),
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
                    Text(l10n.reminderHint, style: const TextStyle(fontSize: 12)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                ref.invalidate(remindersProvider);
                if (context.mounted) Navigator.pop(context);
                // 通知取消/重排在后台执行，不阻塞界面
                unawaited(() async {
                  await NotificationService().cancelReminder(widget.editReminder!.id);
                  if (reminderDt.isAfter(DateTime.now())) {
                    await NotificationService().scheduleReminder(
                      id: widget.editReminder!.id,
                      title: _titleController.text.trim(),
                      body: l10n.reminderNotification(_titleController.text.trim()),
                      scheduledDate: reminderDt,
                      repeatWeekdays: weekdaysStr,
                    );
                  }
                }());
              } else {
                final id = await db.into(db.reminders).insert(companion);
                ref.invalidate(remindersProvider);
                if (context.mounted) Navigator.pop(context);
                // 通知调度在后台进行，不阻塞界面响应
                if (reminderDt.isAfter(DateTime.now())) {
                  unawaited(NotificationService().scheduleReminder(
                    id: id,
                    title: _titleController.text.trim(),
                    body: l10n.reminderNotification(_titleController.text.trim()),
                    scheduledDate: reminderDt,
                    repeatWeekdays: weekdaysStr,
                  ));
                }
              }
            },
            child: Text(widget.editReminder != null ? l10n.save : l10n.add),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}