import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/generated/app_localizations.dart';
import '../notification_service.dart';
import 'battery_optimization.dart';

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

/// 启动时一次性提示开启「自启动 / 允许后台运行」。
/// 国产 ROM 只放行电池优化还不够：没开自启动，划掉应用后系统会冻结闹钟，
/// 提醒要等下次打开应用才补发。只提示一次，之后可在 设置 → 自启动 手动进入。
Future<void> maybePromptAutoStart(BuildContext context) async {
  if (kIsWeb || !Platform.isAndroid) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('permAutoStartPrompted') ?? false) return;
    await prefs.setBool('permAutoStartPrompted', true);
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.autoStartDialogTitle),
        content: Text(l10n.autoStartDialogMessage),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.gotIt)),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              // 跳厂商自启动页；没有对应页面时原生侧会退回应用详情页
              openAutoStartSettings();
            },
            child: Text(l10n.goToSettings),
          ),
        ],
      ),
    );
  } catch (_) {
    // 提示失败不应影响应用启动
  }
}
