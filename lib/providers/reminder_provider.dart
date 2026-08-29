import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart' hide Reminder;
import '../models/reminder.dart';
import '../notification_service.dart';
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

final reminderDateStringsProvider = FutureProvider<List<String>>((ref) async {
  final reminders = await ref.watch(remindersProvider.future);
  return reminders.map((r) => r.dateTime.substring(0, 10)).toSet().toList()..sort();
});

final reminderNotifierProvider = Provider<ReminderNotifier>((ref) {
  return ReminderNotifier(ref);
});

class ReminderNotifier {
  final Ref _ref;
  ReminderNotifier(this._ref);

  Future<void> addReminder(RemindersCompanion companion, {String? notificationBody}) async {
    final db = _ref.read(databaseProvider);
    final id = await db.into(db.reminders).insert(companion);
    final reminderDateTime = companion.reminderDateTime.value;
    final title = companion.title.value;
    final dt = DateTime.parse(reminderDateTime);
    if (dt.isAfter(DateTime.now())) {
      await NotificationService().scheduleReminder(
        id: id,
        title: title,
        body: notificationBody ?? title,
        scheduledDate: dt,
      );
    }
    _ref.invalidate(remindersProvider);
  }

  Future<void> toggleReminder(int id, bool completed) async {
    final db = _ref.read(databaseProvider);
    try {
      await (db.update(db.reminders)
        ..where((t) => t.id.equals(id))).write(RemindersCompanion(isCompleted: Value(completed)));
      if (completed) {
        await NotificationService().cancelReminder(id);
      } else {
        await _rescheduleIfPending(db, id);
      }
    } catch (_) {
      // 通知调度失败不应影响提醒状态的 UI 刷新
    }
    _ref.invalidate(remindersProvider);
  }

  Future<void> _rescheduleIfPending(AppDatabase db, int id) async {
    final rows = await (db.select(db.reminders)..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return;
    final r = rows.first;
    final dt = DateTime.parse(r.reminderDateTime);
    if (dt.isAfter(DateTime.now())) {
      await NotificationService().scheduleReminder(
        id: r.id,
        title: r.title,
        body: r.title,
        scheduledDate: dt,
      );
    }
  }

  Future<void> deleteReminder(int id) async {
    final db = _ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    await NotificationService().cancelReminder(id);
    _ref.invalidate(remindersProvider);
  }
}
