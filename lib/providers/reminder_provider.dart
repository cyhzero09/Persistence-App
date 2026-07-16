import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart' hide Reminder;
import '../models/reminder.dart';
import 'database_provider.dart';

final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.reminders)
    ..orderBy([(t) => OrderingTerm(expression: t.reminderDateTime, mode: OrderingMode.asc)])).get();
  return rows.map((r) => Reminder(
    id: r.id,
    title: r.title,
    dateTime: r.reminderDateTime,
    repeatWeekdays: r.repeatWeekdays,
    repeatEndDate: r.repeatEndDate,
    categoryId: r.categoryId,
    isCompleted: r.isCompleted,
  )).toList();
});

final reminderNotifierProvider = Provider<ReminderNotifier>((ref) {
  return ReminderNotifier(ref);
});

class ReminderNotifier {
  final Ref _ref;
  ReminderNotifier(this._ref);

  Future<void> addReminder(RemindersCompanion companion) async {
    final db = _ref.read(databaseProvider);
    await db.into(db.reminders).insert(companion);
    _ref.invalidate(remindersProvider);
  }

  Future<void> toggleReminder(int id, bool completed) async {
    final db = _ref.read(databaseProvider);
    await (db.update(db.reminders)
      ..where((t) => t.id.equals(id))).write(RemindersCompanion(isCompleted: Value(completed)));
    _ref.invalidate(remindersProvider);
  }

  Future<void> deleteReminder(int id) async {
    final db = _ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    _ref.invalidate(remindersProvider);
  }
}
