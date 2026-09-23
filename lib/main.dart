import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'app_version.dart';
import 'cloud_service.dart';
import 'notification_service.dart';
import 'database/database.dart' hide CheckInCategory;
import 'database/executor.dart';
import 'models/check_in_category.dart';
import 'models/reminder.dart' as rem;

/// 启动时用当前（已修正的）时区把所有尚未完成的提醒、以及所有开启了
/// 打卡提醒的项目重新调度一遍。修复时区/升级后，旧的错误调度会被覆盖。
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
    final catRows = await db.select(db.checkInCategories).get();
    final categories = catRows.map((c) => CheckInCategory(
      id: c.id,
      name: c.name,
      emoji: c.emoji,
      description: c.description,
      startTime: c.startTime,
      endTime: c.endTime,
      repeatWeekdays: c.repeatWeekdays,
      reminderTime: c.reminderTime,
      isDefault: c.isDefault,
    )).toList();
    await NotificationService().resyncPending(reminders, categories: categories);
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
  await loadAppVersion();
  // 云端不可用（如未配置 google-services.json）只降级，不阻塞启动
  await CloudService().init();
  await NotificationService().init();
  await _resyncReminders();
  runApp(const ProviderScope(child: DailyTrackerApp()));
}
