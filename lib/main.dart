import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'notification_service.dart';
import 'database/database.dart';
import 'database/executor.dart';
import 'models/reminder.dart' as rem;

/// 启动时用当前（已修正的）时区把所有尚未完成的提醒重新调度一遍。
/// 修复时区/升级后，旧的错误调度会被覆盖，保证提醒能正常触发。
Future<void> _resyncReminders() async {
  if (kIsWeb) return;
  try {
    final db = AppDatabase(createExecutor());
    final rows = await db.select(db.reminders).get();
    final reminders = rows.map((r) => rem.Reminder(
      id: r.id,
      title: r.title,
      dateTime: r.reminderDateTime,
      repeatWeekdays: r.repeatWeekdays,
      repeatEndDate: r.repeatEndDate,
      categoryId: r.categoryId,
      isCompleted: r.isCompleted,
    )).toList();
    await NotificationService().resyncPending(reminders);
    await db.close();
  } catch (_) {
    // 重建失败不应阻塞 App 启动
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('en');
  await initializeDateFormatting('zh');
  await initializeDateFormatting('zh-TW');
  await NotificationService().init();
  await _resyncReminders();
  runApp(const ProviderScope(child: DailyTrackerApp()));
}
