import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app.dart';
import 'app_version.dart';
import 'cloud_service.dart';
import 'notification_service.dart';
import 'database/database.dart';
import 'database/executor.dart';

/// 启动时用当前（已修正的）时区重建所有系统闹钟：
/// 未完成的提醒 + 所有开启了打卡提醒的项目（今天已打卡的跳过今天那次）。
Future<void> _resyncReminders() async {
  if (kIsWeb) return;
  try {
    final db = AppDatabase(createExecutor());
    await NotificationService().resyncFromDatabase(db);
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
