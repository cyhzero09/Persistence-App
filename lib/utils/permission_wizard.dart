import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../notification_service.dart';

/// 启动时自动权限引导：依次检查并请求
/// 1. 通知权限（Android 13+ 系统授权框）
/// 2. 精确闹钟权限（Android 12+ 引导到系统设置）
/// 3. 电池优化白名单（系统请求对话框）
///
/// 用户拒绝电池优化后记录 flag（permDeniedBattery），避免每次启动骚扰；
/// 之后可在 设置 → 电池优化 手动修复。
Future<void> runStartupPermissionCheck() async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final service = NotificationService();
    final prefs = await SharedPreferences.getInstance();

    // 1. 通知权限
    if (!await service.areNotificationsEnabled()) {
      await service.requestNotificationsPermission();
    }

    // 2. 精确闹钟
    if (!await service.canScheduleExact()) {
      await service.requestExactAlarmPermission();
    }

    // 3. 电池优化白名单
    if (!prefs.getBool('permDeniedBattery')!) {
      if (!await service.isIgnoringBatteryOptimization()) {
        final granted = await service.requestIgnoreBatteryOptimization();
        if (!granted) {
          await prefs.setBool('permDeniedBattery', true);
        }
      }
    }
  } catch (_) {
    // 权限引导失败不应影响应用启动
  }
}
