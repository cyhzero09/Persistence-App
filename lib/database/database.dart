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
  int get schemaVersion => 5;

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
      },
    );
  }

  Future<void> _seedDefaultCategories() async {
    final defaults = [
      ('運動', '🏃'),
      ('閱讀', '📚'),
      ('喝水', '💧'),
      ('冥想', '🧘'),
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
