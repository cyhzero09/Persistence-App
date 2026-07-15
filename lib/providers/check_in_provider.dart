import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import 'database_provider.dart';

final categoriesProvider = FutureProvider<List<CheckInCategory>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await db.select(db.checkInCategories).get();
  return rows.map((r) => CheckInCategory(
    id: r.id,
    name: r.name,
    emoji: r.emoji,
    isDefault: r.isDefault,
  )).toList();
});

final checkInRecordsForDateProvider = FutureProvider.family<List<CheckInRecord>, String>((ref, date) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.checkInRecords)
    ..where((t) => t.date.equals(date))).get();
  return rows.map((r) => CheckInRecord(
    id: r.id,
    categoryId: r.categoryId,
    date: r.date,
    isCompleted: r.isCompleted,
    note: r.note,
  )).toList();
});

final checkInRecordDatesProvider = FutureProvider<List<String>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await db.select(db.checkInRecords).get();
  final dates = rows.map((r) => r.date).toSet().toList()..sort();
  return dates;
});
