import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'models/reminder.dart';
import 'models/check_in_category.dart';
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
    String? repeatEndDate,
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
        repeatEndDate: repeatEndDate,
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
    String? repeatEndDate,
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
      // 重复截止日：晚于截止日的下一次触发不再排定（原先该字段被存下但从未生效）
      final end = _parseEndDate(repeatEndDate);
      if (end != null && _dateOnly(fireAt).isAfter(end)) {
        await _plugin.cancel(id);
        return;
      }
    } else {
      // 一次性提醒：时间已过则无需再触发。
      if (scheduledDate.isBefore(now)) {
        await _plugin.cancel(id);
        return;
      }
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

  /// 返回当前设备可用的 Android 调度模式。
  /// 优先 alarmClock：系统把它当"闹钟"对待（最不容易被国产 ROM 的后台冻结拦下），
  /// 其次 exactAllowWhileIdle，最后退回 inexactAllowWhileIdle（会被 Doze/冻结延迟）。
  Future<AndroidScheduleMode> _scheduleMode() async {
    if (kIsWeb) return AndroidScheduleMode.inexact;
    return await canScheduleExact()
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// 当前调度模式的可读名称（供设置页诊断展示）。
  Future<String> scheduleModeName() async {
    if (kIsWeb) return 'unsupported';
    return await canScheduleExact() ? 'alarmClock' : 'inexact';
  }

  /// 当前已注册到系统的提醒条数（供设置页诊断展示）。
  Future<int> pendingCount() async {
    if (kIsWeb) return 0;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      return pending.length;
    } catch (_) {
      return 0;
    }
  }

  /// 解析重复截止日（yyyy-MM-dd），非法或为空返回 null。
  DateTime? _parseEndDate(String? repeatEndDate) {
    if (repeatEndDate == null || repeatEndDate.trim().isEmpty) return null;
    final d = DateTime.tryParse(repeatEndDate.trim());
    if (d == null) return null;
    return _dateOnly(d);
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

  /// 打卡提醒的通知 id 命名空间，与 reminders 表的自增 id 隔开，避免互相覆盖。
  static const int _checkInIdBase = 1000000;

  /// 某个打卡项目的提醒通知 id。
  int checkInNotificationId(int categoryId) => _checkInIdBase + categoryId;

  /// 排定/更新某个打卡项目的提醒。
  /// 提醒属于打卡项目自身（不在 reminders 表里建记录）：开关打开就按
  /// [repeatWeekdays] 每周循环触发，直到开关关闭或项目被删除。
  /// 标题固定为「emoji + 名称」、无正文，这样启动重建后的通知样式与创建时完全一致。
  Future<void> scheduleCheckInReminder({
    required int categoryId,
    required String emoji,
    required String name,
    required String time,
    String? repeatWeekdays,
  }) async {
    final parts = time.split(':');
    if (parts.length != 2) return;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return;
    final now = DateTime.now();
    await scheduleReminder(
      id: checkInNotificationId(categoryId),
      title: '$emoji $name',
      body: '',
      scheduledDate: DateTime(now.year, now.month, now.day, hour, minute),
      // 项目没有勾选星期时按每天处理，避免退化成一次性提醒
      repeatWeekdays: (repeatWeekdays == null || repeatWeekdays.trim().isEmpty)
          ? '0,1,2,3,4,5,6'
          : repeatWeekdays,
    );
  }

  /// 取消某个打卡项目的提醒（关闭开关或删除项目时调用）。
  Future<void> cancelCheckInReminder(int categoryId) async {
    if (kIsWeb) return;
    await _plugin.cancel(checkInNotificationId(categoryId));
  }

  /// 启动时调用：清空旧的（可能是错误时区/错误调度模式的）调度，并按当前逻辑重建
  /// 所有尚未完成的提醒 + 所有开启了提醒的打卡项目。这样修复后无需重装也能恢复正常触发。
  Future<void> resyncPending(
    List<Reminder> reminders, {
    List<CheckInCategory> categories = const [],
  }) async {
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
          repeatEndDate: r.repeatEndDate,
        );
      } catch (e) {
        // 单条失败不影响其余提醒的重建
        // ignore: avoid_print
        debugPrint('resync reminder ${r.id} failed: $e');
      }
    }
    for (final c in categories) {
      if (!c.hasReminder) continue;
      try {
        await scheduleCheckInReminder(
          categoryId: c.id,
          emoji: c.emoji,
          name: c.name,
          time: c.reminderTime!,
          repeatWeekdays: c.repeatWeekdays,
        );
      } catch (e) {
        // ignore: avoid_print
        debugPrint('resync check-in reminder ${c.id} failed: $e');
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
