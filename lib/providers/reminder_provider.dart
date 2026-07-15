import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/reminder.dart';
import 'database_provider.dart';

final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.reminders)
    ..orderBy([(t) => OrderingTerm(expression: t.reminderDateTime, mode: OrderingMode.asc)])).get();
  return rows.map((r) => Reminder(
    id: r.id,
    title: r.title,
    dateTime: r.reminderDateTime,
    categoryId: r.categoryId,
    isCompleted: r.isCompleted,
  )).toList();
});
