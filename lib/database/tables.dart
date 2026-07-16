import 'package:drift/drift.dart';

class CheckInCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  TextColumn get description => text().nullable()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class CheckInRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(CheckInCategories, #id)();
  TextColumn get date => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
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
