import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

const MethodChannel _channel = MethodChannel('app/persistence');

bool get _channelAvailable => !kIsWeb && Platform.isAndroid;

/// 应用是否已在电池优化白名单中（非 Android 平台视为 true）。
Future<bool> isIgnoringBatteryOptimization() async {
  if (!_channelAvailable) return true;
  try {
    return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimization') ?? true;
  } catch (_) {
    return true;
  }
}

/// 弹出系统「忽略电池优化」请求对话框，返回请求后是否已在白名单中。
Future<bool> requestIgnoreBatteryOptimization() async {
  if (!_channelAvailable) return true;
  try {
    return await _channel.invokeMethod<bool>('requestIgnoreBatteryOptimization') ?? true;
  } catch (_) {
    return false;
  }
}
