import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide Reminder;
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/reminder.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminders)),
      body: remindersAsync.when(
        data: (reminders) => reminders.isEmpty
            ? Center(child: Text(l10n.noReminders))
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
      subtitle: Text(DateFormat('M/d HH:mm', intlLocaleOf(context)).format(dt)),
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
          Text(l10n.addReminder, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: l10n.title, border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(DateFormat('yyyy/M/d HH:mm', intlLocaleOf(context)).format(_dateTime)),
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
              decoration: InputDecoration(labelText: l10n.bindCheckInOptional),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.noBinding)),
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
              ref.read(reminderNotifierProvider).addReminder(
                RemindersCompanion.insert(
                  title: _titleController.text.trim(),
                  reminderDateTime: _dateTime.toIso8601String(),
                  categoryId: _selectedCategoryId != null ? Value(_selectedCategoryId!) : const Value.absent(),
                ),
                notificationBody: l10n.reminderNotification(_titleController.text.trim()),
              );
              Navigator.pop(context);
            },
            child: Text(l10n.add),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
