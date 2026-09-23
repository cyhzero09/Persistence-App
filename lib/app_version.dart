import 'package:package_info_plus/package_info_plus.dart';

/// 已安装 APK 的真实版本号，启动时从系统读取。
/// 以前这里是手写常量（长期停在 1.2.6 而 pubspec 已到 1.2.18），
/// 发版时经常忘记同步，导致设置页显示的版本和「检查更新」比对用的版本都是错的。
String appVersion = '1.0.0';

/// 启动时调用。读取失败保留兜底值，不影响启动。
Future<void> loadAppVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    if (info.version.isNotEmpty) appVersion = info.version;
  } catch (_) {
    // 读不到就用兜底值
  }
}