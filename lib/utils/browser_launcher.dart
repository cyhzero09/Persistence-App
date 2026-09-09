import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

const MethodChannel _channel = MethodChannel('app/persistence');

/// 用外部浏览器打开 URL。
/// Android 走 CATEGORY_APP_BROWSER 原生通道（只匹配浏览器，避免被 GitHub
/// 客户端的 App Links 接管）；原生不可用或其它平台回退 launchUrl。
Future<bool> openInBrowser(String url) async {
  if (!kIsWeb && Platform.isAndroid) {
    try {
      final handled = await _channel.invokeMethod<bool>('openInBrowser', {'url': url});
      if (handled == true) return true;
    } catch (_) {
      // 通道不可用时走通用回退
    }
  }
  return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
}
