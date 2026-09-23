import 'package:drift/drift.dart';

class CheckInCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  TextColumn get description => text().nullable()();
  TextColumn get startTime => text().nullable()();
  TextColumn get endTime => text().nullable()();
  TextColumn get repeatWeekdays => text().nullable()();
  /// 打卡提醒时间（HH:mm）。null = 未开启提醒。
  /// 提醒属于打卡项目自身：打开开关就按 repeatWeekdays 每周循环触发，
  /// 不在 reminders 表里另建一条记录。
  TextColumn get reminderTime => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class CheckInRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(CheckInCategories, #id)();
  TextColumn get date => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get completedAt => text().nullable()();
}

class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()();
  TextColumn get title => text().nullable()();
  TextColumn get content => text()();
  IntColumn get checkInRecordId => integer().nullable().references(CheckInRecords, #id)();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get reminderDateTime => text()();
  TextColumn get repeatWeekdays => text().nullable()();
  TextColumn get repeatEndDate => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(CheckInCategories, #id)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}
