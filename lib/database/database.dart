import 'package:drift/drift.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  CheckInCategories,
  CheckInRecords,
  DiaryEntries,
  Reminders,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor executor) : super(executor);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaultCategories();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(checkInCategories, checkInCategories.description);
          await m.addColumn(diaryEntries, diaryEntries.title);
          await m.addColumn(reminders, reminders.repeatWeekdays);
          await m.addColumn(reminders, reminders.repeatEndDate);
        }
        if (from < 3) {
          await m.addColumn(checkInCategories, checkInCategories.startTime);
        }
        if (from < 4) {
          await m.addColumn(checkInRecords, checkInRecords.completedAt);
        }
        if (from < 5) {
          await m.addColumn(checkInCategories, checkInCategories.endTime);
          await m.addColumn(checkInCategories, checkInCategories.repeatWeekdays);
        }
        if (from < 6) {
          // 打卡提醒改为打卡项目自己的字段：把 v1.2.18 期间
          // 写进 reminders 表、用 category_id 关联的那些行搬回来并删掉，
          // 避免它们在「提醒」列表里以独立条目出现。
          await m.addColumn(checkInCategories, checkInCategories.reminderTime);
          await customStatement(
            'UPDATE check_in_categories SET reminder_time = ('
            '  SELECT substr(r.reminder_date_time, 12, 5) FROM reminders r'
            '  WHERE r.category_id = check_in_categories.id AND r.is_completed = 0'
            '  ORDER BY r.id LIMIT 1)',
          );
          await customStatement('DELETE FROM reminders WHERE category_id IS NOT NULL');
        }
      },
    );
  }

  Future<void> _seedDefaultCategories() async {
    final defaults = [
      ('Exercise', '🏃'),
      ('Reading', '📚'),
      ('Water', '💧'),
      ('Meditation', '🧘'),
    ];
    for (final (name, emoji) in defaults) {
      await into(checkInCategories).insert(CheckInCategoriesCompanion.insert(
        name: name,
        emoji: emoji,
        isDefault: const Value(true),
      ));
    }
  }
}
