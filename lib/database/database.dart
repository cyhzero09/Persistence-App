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
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedDefaultCategories();
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
