import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'models/reminder.dart';
import 'utils/battery_optimization.dart' as bat;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Android 平台实现（供权限检查/请求使用；Web 返回 null）
  AndroidFlutterLocalNotificationsPlugin? get androidImpl =>
      kIsWeb ? null : _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    // 必须使用设备真实的 IANA 时区名（如 'Asia/Shanghai'）设置本地时区：
    // zonedSchedule 会把 location.name 传给 Android 原生 java.time.ZoneId.of() 解析，
    // 自定义名字（如 'LOCAL'）会导致 "Unknown time-zone ID" 异常，闹钟永远注册不上。
    try {
      final timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      // 兜底：拿不到 IANA 名时用 UTC 偏移构建固定时区。
      // 命名 "GMT+08:00" 是 java.time.ZoneId.of 的合法格式（固定偏移、无 DST）。
      final offset = DateTime.now().timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final h = offset.inHours.abs().toString().padLeft(2, '0');
      final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
      final name = 'GMT$sign$h:$m';
      tz.setLocalLocation(tz.Location(
        name,
        [],
        [],
        [tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: name)],
      ));
    }
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    await _plugin.initialize(settings);
    if (!kIsWeb) {
      // Android 13+ (API 33+) requires runtime permission to show notifications
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? repeatWeekdays,
    String channelName = 'Reminders',
    String channelDescription = 'Daily check-in reminders',
  }) async {
    if (!_initialized) await init();
    if (kIsWeb) return;

    try {
      await _scheduleReminder(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        repeatWeekdays: repeatWeekdays,
        channelName: channelName,
        channelDescription: channelDescription,
      );
    } catch (e) {
      // 调度失败必须留下日志，否则到点不响时无从排查
      debugPrint('scheduleReminder id=$id FAILED: $e');
    }
  }

  Future<void> _scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? repeatWeekdays,
    required String channelName,
    required String channelDescription,
  }) async {
    final now = DateTime.now();
    // 计算实际触发的本地时间点，以及是否需要按周/按天循环。
    final weekdaySet = _parseWeekdays(repeatWeekdays);
    DateTime fireAt = scheduledDate;
    DateTimeComponents components = DateTimeComponents.dateAndTime;

    if (weekdaySet != null) {
      // 全部 7 天 → 每天循环；否则 → 在指定星期几循环。
      if (weekdaySet.length == 7) {
        components = DateTimeComponents.time;
        fireAt = _nextTimeOccurrence(now, scheduledDate);
      } else {
        components = DateTimeComponents.dayOfWeekAndTime;
        fireAt = _nextWeekdayOccurrence(now, scheduledDate, weekdaySet);
      }
    } else {
      // 一次性提醒：时间已过则无需再触发。
      if (scheduledDate.isBefore(now)) return;
    }

    final androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    final location = tz.local;
    final tzFireAt = tz.TZDateTime.from(fireAt, location);

    // ignore: avoid_print
    debugPrint('scheduleReminder id=$id at ${tzFireAt.toLocal()} $components');
    // 优先用精确闹钟（保证到点准时触发）；系统不允许精确时退回不精确模式。
    // Android 12+ 默认拒绝精确闹钟，但 USE_EXACT_ALARM 对侧载应用自动授予。
    final mode = await _scheduleMode();
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzFireAt,
      details,
      androidScheduleMode: mode,
      matchDateTimeComponents: components,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 返回当前设备可用的 Android 调度模式：优先精确，无法精确则退回不精确。
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (kIsWeb) return AndroidScheduleMode.inexact;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      final canExact = await android?.canScheduleExactNotifications() ?? false;
      return canExact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle;
    } catch (_) {
      return AndroidScheduleMode.inexactAllowWhileIdle;
    }
  }

  /// 是否可精确调度（供 UI 判断是否需要引导用户开启精确闹钟权限）。
  Future<bool> canScheduleExact() async {
    if (kIsWeb) return false;
    final android =
        _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    try {
      return await android?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 启动时调用：清空旧的（可能是错误时区排的）调度，并按当前逻辑重建所有
  /// 尚未完成的提醒。这样修复时区后无需重装也能恢复正常触发。
  Future<void> resyncPending(List<Reminder> reminders) async {
    if (_initialized == false) await init();
    if (kIsWeb) return;
    // 先清除所有旧调度，避免沿用旧版本错误时区/重复的取消残留。
    if (!kIsWeb) await _plugin.cancelAll();
    for (final r in reminders) {
      if (r.isCompleted) continue;
      final dt = DateTime.parse(r.dateTime);
      try {
        await scheduleReminder(
          id: r.id,
          title: r.title,
          body: r.title,
          scheduledDate: dt,
          repeatWeekdays: r.repeatWeekdays,
        );
      } catch (e) {
        // 单条失败不影响其余提醒的重建
        // ignore: avoid_print
        debugPrint('resync reminder ${r.id} failed: $e');
      }
    }
  }

  /// 解析 repeatWeekdays（0=周一 … 6=周日，逗号分隔）为 {1=周一 … 7=周日}；
  /// 为 null 或为空返回 null（表示一次性提醒）。
  Set<int>? _parseWeekdays(String? repeatWeekdays) {
    if (repeatWeekdays == null || repeatWeekdays.trim().isEmpty) return null;
    final parsed = <int>{};
    for (final part in repeatWeekdays.split(',')) {
      final v = int.tryParse(part.trim());
      if (v == null || v < 0 || v > 6) continue;
      parsed.add(v + 1); // 0=周一→1 … 6=周日→7
    }
    return parsed.isEmpty ? null : parsed;
  }

  /// 从 [from] 以后、包含 [base] 当天及后续，取下一个 target 时刻（保留 [base] 的时分）。
  DateTime _nextTimeOccurrence(DateTime from, DateTime base) {
    final candidate = DateTime(from.year, from.month, from.day, base.hour, base.minute);
    return candidate.isAfter(from) ? candidate : candidate.add(const Duration(days: 1));
  }

  /// 从 [from] 以后找到最近的、星期几在 [weekdays] 中的触发时刻（保留 [base] 的时分）。
  DateTime _nextWeekdayOccurrence(DateTime from, DateTime base, Set<int> weekdays) {
    var candidate = DateTime(from.year, from.month, from.day, base.hour, base.minute);
    for (var i = 0; i < 8; i++) {
      if (candidate.isAfter(from) && weekdays.contains(candidate.weekday)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
    return _nextTimeOccurrence(from, base);
  }

  Future<void> cancelReminder(int id) async {
    if (kIsWeb) return;
    await _plugin.cancel(id);
  }

  /// 通知权限是否已授予（Android）。
  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return true;
    return await androidImpl?.areNotificationsEnabled() ?? true;
  }

  /// 请求通知权限（Android 13+ 首次会弹系统授权框）。
  Future<bool> requestNotificationsPermission() async {
    if (kIsWeb) return true;
    return await androidImpl?.requestNotificationsPermission() ?? true;
  }

  /// 请求精确闹钟权限（Android 12+ 会引导到系统设置）。
  Future<bool> requestExactAlarmPermission() async {
    if (kIsWeb) return true;
    try {
      await androidImpl?.requestExactAlarmsPermission();
    } catch (_) {}
    return canScheduleExact();
  }

  /// 是否在电池优化白名单中。
  Future<bool> isIgnoringBatteryOptimization() async {
    return await bat.isIgnoringBatteryOptimization();
  }

  /// 请求加入电池优化白名单，返回是否已加入。
  Future<bool> requestIgnoreBatteryOptimization() async {
    return await bat.requestIgnoreBatteryOptimization();
  }
}
