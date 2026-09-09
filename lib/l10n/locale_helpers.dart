import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// Returns the intl-style locale tag for the current app locale,
/// e.g. 'en', 'zh', 'zh-TW'.
String intlLocaleOf(BuildContext context) {
  return Localizations.localeOf(context).toLanguageTag();
}

bool _isChinese(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'zh';
}

/// Sunday-first short weekday labels for calendar headers.
List<String> calendarWeekdayLabels(BuildContext context) {
  if (_isChinese(context)) {
    return const ['日', '一', '二', '三', '四', '五', '六'];
  }
  return const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
}

/// Monday-first short weekday labels for repeat-day chips (index 0 = Monday).
List<String> chipWeekdayLabels(BuildContext context) {
  if (_isChinese(context)) {
    return const ['一', '二', '三', '四', '五', '六', '日'];
  }
  return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
}

/// Localized separator used when joining a list of weekday names.
String listSeparatorOf(BuildContext context) {
  return _isChinese(context) ? '、' : ', ';
}

/// Localized home page app-bar date title (slash-style date).
String homeDateTitle(BuildContext context, DateTime date) {
  if (_isChinese(context)) {
    return DateFormat('yyyy/MM/dd EEEE', intlLocaleOf(context)).format(date);
  }
  return DateFormat('EEE, MM/dd/yyyy', intlLocaleOf(context)).format(date);
}

/// Short weekday label for a [DateTime] (used in full-month view).
String weekdayLabelOf(BuildContext context, DateTime date) {
  return calendarWeekdayLabels(context)[date.weekday % 7];
}
