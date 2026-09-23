import 'dart:convert';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide CheckInCategory, CheckInRecord, DiaryEntry, Reminder;
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';

/// 备份文件结构版本。加字段时递增，[applyBackupJson] 按此兼容旧备份。
const int backupFormatVersion = 1;

/// 构建完整备份 JSON。本地「导出备份」与「上传存档到云端」共用同一份结构。
Future<String> buildBackupJson(AppDatabase db) async {
  final cats = await db.select(db.checkInCategories).get();
  final records = await db.select(db.checkInRecords).get();
  final diaries = await db.select(db.diaryEntries).get();
  final reminders = await db.select(db.reminders).get();

  final data = {
    'version': backupFormatVersion,
    'exportDate': DateTime.now().toIso8601String(),
    'categories': cats
        .map((r) => CheckInCategory(
              id: r.id,
              name: r.name,
              emoji: r.emoji,
              description: r.description,
              startTime: r.startTime,
              endTime: r.endTime,
              repeatWeekdays: r.repeatWeekdays,
              reminderTime: r.reminderTime,
              isDefault: r.isDefault,
            ).toJson())
        .toList(),
    'records': records
        .map((r) => CheckInRecord(
              id: r.id,
              categoryId: r.categoryId,
              date: r.date,
              isCompleted: r.isCompleted,
              note: r.note,
              completedAt: r.completedAt,
            ).toJson())
        .toList(),
    'diaries': diaries
        .map((r) => DiaryEntry(
              id: r.id,
              date: r.date,
              title: r.title,
              content: r.content,
              checkInRecordId: r.checkInRecordId,
            ).toJson())
        .toList(),
    'reminders': reminders
        .map((r) => Reminder(
              id: r.id,
              title: r.title,
              dateTime: r.reminderDateTime,
              repeatWeekdays: r.repeatWeekdays,
              repeatEndDate: r.repeatEndDate,
              categoryId: r.categoryId,
              isCompleted: r.isCompleted,
            ).toJson())
        .toList(),
  };

  return const JsonEncoder.withIndent('  ').convert(data);
}

/// 用备份 JSON 覆盖本机数据（本地「导入备份」与「从云端恢复」共用）。
/// 会先清空现有打卡项目、打卡记录、日记和提醒。
Future<void> applyBackupJson(AppDatabase db, String jsonStr) async {
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;

  await db.delete(db.reminders).go();
  await db.delete(db.diaryEntries).go();
  await db.delete(db.checkInRecords).go();
  await db.delete(db.checkInCategories).go();

  for (final c in json['categories'] as List) {
    final m = CheckInCategory.fromJson(c as Map<String, dynamic>);
    await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
          name: m.name,
          emoji: m.emoji,
          description: m.description != null ? Value(m.description!) : const Value.absent(),
          startTime: m.startTime != null ? Value(m.startTime!) : const Value.absent(),
          endTime: m.endTime != null ? Value(m.endTime!) : const Value.absent(),
          repeatWeekdays: m.repeatWeekdays != null ? Value(m.repeatWeekdays!) : const Value.absent(),
          reminderTime: m.reminderTime != null ? Value(m.reminderTime!) : const Value.absent(),
          isDefault: Value(m.isDefault),
        ));
  }
  for (final r in json['records'] as List) {
    final m = CheckInRecord.fromJson(r as Map<String, dynamic>);
    await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: m.categoryId,
          date: m.date,
          isCompleted: Value(m.isCompleted),
          note: Value(m.note),
          completedAt: m.completedAt != null ? Value(m.completedAt!) : const Value.absent(),
        ));
  }
  for (final d in json['diaries'] as List) {
    final m = DiaryEntry.fromJson(d as Map<String, dynamic>);
    await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
          date: m.date,
          title: m.title != null ? Value(m.title!) : const Value.absent(),
          content: m.content,
          checkInRecordId: Value(m.checkInRecordId),
        ));
  }
  for (final r in json['reminders'] as List) {
    final m = Reminder.fromJson(r as Map<String, dynamic>);
    await db.into(db.reminders).insert(RemindersCompanion.insert(
          title: m.title,
          reminderDateTime: m.dateTime,
          repeatWeekdays: m.repeatWeekdays != null ? Value(m.repeatWeekdays!) : const Value.absent(),
          repeatEndDate: m.repeatEndDate != null ? Value(m.repeatEndDate!) : const Value.absent(),
          isCompleted: Value(m.isCompleted),
          categoryId: m.categoryId != null ? Value(m.categoryId!) : const Value.absent(),
        ));
  }
}