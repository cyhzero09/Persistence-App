import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide Reminder;
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/reminder.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('提醒')),
      body: remindersAsync.when(
        data: (reminders) => reminders.isEmpty
            ? const Center(child: Text('尚無提醒'))
            : ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (_, i) => _ReminderTile(reminder: reminders[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('載入失敗')),
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
      subtitle: Text(DateFormat('M/d HH:mm', 'zh-TW').format(dt)),
      leading: Checkbox(
        value: reminder.isCompleted,
        onChanged: (v) => ref.read(reminderNotifierProvider).toggleReminder(reminder.id, v ?? false),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(reminderNotifierProvider).deleteReminder(reminder.id),
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  const _AddReminderSheet();

  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleController = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  int? _selectedCategoryId;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('新增提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                firstDate: DateTime.now(),
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
              ref.read(reminderNotifierProvider).addReminder(RemindersCompanion.insert(
                title: _titleController.text.trim(),
                reminderDateTime: _dateTime.toIso8601String(),
                categoryId: _selectedCategoryId != null ? Value(_selectedCategoryId!) : const Value.absent(),
              ));
              Navigator.pop(context);
            },
            child: const Text('新增'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
