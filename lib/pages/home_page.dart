import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/check_in_tile.dart';
import '../widgets/check_in_dialog.dart';
import '../providers/diary_provider.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  Set<DateTime> _parseMarkedDates(List<String> dateStrings) {
    return dateStrings.map((s) {
      final parts = s.split('-');
      return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final recordsAsync = ref.watch(checkInRecordsForDateProvider(dateStr));
    final datesAsync = ref.watch(checkInRecordDatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('yyyy 年 M 月 d 日', 'zh-TW').format(_selectedDate))),
      body: Column(
        children: [
          datesAsync.when(
            data: (dates) => CalendarWidget(
              selectedDate: _selectedDate,
              markedDates: _parseMarkedDates(dates),
              onDateSelected: (day) => setState(() => _selectedDate = day),
            ),
            loading: () => const SizedBox(height: 300, child: Center(child: CircularProgressIndicator())),
            error: (_, __) => const SizedBox(height: 300),
          ),
          const Divider(height: 1),
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => recordsAsync.when(
                data: (records) {
                  return ListView(
                    children: categories.map((cat) {
                      final record = records.where((r) => r.categoryId == cat.id).toList();
                      final existing = record.isNotEmpty ? record.first : null;
                      return CheckInTile(
                        category: cat,
                        isCompleted: existing?.isCompleted ?? false,
                        note: existing?.note,
                        onToggle: (value) => _toggleCheckIn(cat.id, dateStr, value ?? false, existing),
                        onAddNote: () => _showNoteDialog(cat.id, dateStr, existing),
                      );
                    }).toList(),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('載入失敗')),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('載入失敗')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCheckIn(int categoryId, String dateStr, bool completed, dynamic existing) async {
    final db = ref.read(databaseProvider);
    if (existing != null) {
      await (db.update(db.checkInRecords)
        ..where((t) => t.id.equals(existing.id))).write(const CheckInRecordsCompanion(isCompleted: Value(true)));
    } else {
      await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
        categoryId: categoryId,
        date: dateStr,
        isCompleted: const Value(true),
      ));
    }
    ref.invalidate(checkInRecordsForDateProvider(dateStr));
    ref.invalidate(checkInRecordDatesProvider);
  }

  Future<void> _showNoteDialog(int categoryId, String dateStr, dynamic existing) async {
    final note = await showDialog<String>(context: context, builder: (_) => CheckInNoteDialog(initialNote: existing?.note));
    if (note != null) {
      final db = ref.read(databaseProvider);
      int? recordId;
      if (existing != null) {
        await (db.update(db.checkInRecords)
          ..where((t) => t.id.equals(existing.id))).write(CheckInRecordsCompanion(note: Value(note)));
        recordId = existing.id;
      } else {
        recordId = await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
          categoryId: categoryId,
          date: dateStr,
          note: Value(note),
        ));
      }
      // Also create a diary entry from the note
      await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
        date: '$dateStr ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}:00',
        content: note,
        checkInRecordId: Value(recordId),
      ));
      ref.invalidate(checkInRecordsForDateProvider(dateStr));
      ref.invalidate(checkInRecordDatesProvider);
      ref.invalidate(diaryEntriesProvider);
    }
  }
}
