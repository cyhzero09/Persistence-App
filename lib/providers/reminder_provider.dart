import 'dart:async';
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
    _ref.invalidate(remindersProvider);
    final dt = DateTime.parse(companion.reminderDateTime.value);
    // 通知调度在后台进行，不阻塞界面刷新
    unawaited(NotificationService().scheduleReminder(
      id: id,
      title: companion.title.value,
      body: notificationBody ?? companion.title.value,
      scheduledDate: dt,
      repeatWeekdays: _clampWeekdays(companion),
    ));
  }

  /// 安全读取 companion 中的 repeatWeekdays（可能为 Value.absent()）。
  String? _clampWeekdays(RemindersCompanion companion) {
    try {
      return companion.repeatWeekdays.value;
    } catch (_) {
      return null;
    }
  }

  Future<void> toggleReminder(int id, bool completed) async {
    final db = _ref.read(databaseProvider);
    await (db.update(db.reminders)
      ..where((t) => t.id.equals(id))).write(RemindersCompanion(isCompleted: Value(completed)));
    // 先刷新 UI，通知操作后台执行，避免卡顿
    _ref.invalidate(remindersProvider);
    try {
      if (completed) {
        await NotificationService().cancelReminder(id);
      } else {
        await _rescheduleIfPending(db, id);
      }
    } catch (_) {
      // 通知调度失败不应影响提醒状态的 UI 刷新
    }
  }

  Future<void> _rescheduleIfPending(AppDatabase db, int id) async {
    final rows = await (db.select(db.reminders)..where((t) => t.id.equals(id))).get();
    if (rows.isEmpty) return;
    final r = rows.first;
    final dt = DateTime.parse(r.reminderDateTime);
    // 重复提醒即使当天时间已过，也会调度下一次触发
    await NotificationService().scheduleReminder(
      id: r.id,
      title: r.title,
      body: r.title,
      scheduledDate: dt,
      repeatWeekdays: r.repeatWeekdays,
    );
  }

  Future<void> deleteReminder(int id) async {
    final db = _ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    // 先刷新 UI，取消通知后台执行，避免卡顿
    _ref.invalidate(remindersProvider);
    unawaited(NotificationService().cancelReminder(id));
  }
}
