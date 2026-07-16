import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/diary_entry.dart';
import 'database_provider.dart';

final diaryEntriesProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.diaryEntries)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  return rows.map((r) => DiaryEntry(
    id: r.id,
    date: r.date,
    title: r.title,
    content: r.content,
    checkInRecordId: r.checkInRecordId,
  )).toList();
});
