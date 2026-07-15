# Daily Tracker App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use subagent-driven-development (recommended) or executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Note:** Local notifications (`flutter_local_notifications`) require native device support. They work on iOS/Android but NOT on Flutter Web. For Web development, the reminder UI and data model work fully; notifications will fire only on mobile builds. Set up `flutter_local_notifications` as a separate mobile-only task after the core app is complete.

**Goal:** Build a personal daily check-in, reminder, and diary app with Flutter + SQLite.

**Architecture:** Flutter app with Riverpod for state management, drift (SQLite) for persistence, bottom tab navigation with 5 pages. Local-first with optional future cloud sync.

**Tech Stack:** Flutter 3.27+, Dart, drift (SQLite), Riverpod, flutter_local_notifications

## Global Constraints

- All UI text in Traditional Chinese (zh-TW)
- No cloud sync in v1
- Predefined categories: 運動 🏃, 閱讀 📚, 喝水 💧, 冥想 🧘
- Categories use emoji for icons
- Bottom tab bar with 5 tabs: 首頁, 時間軸, 日記, 提醒, 設定
- App opens to today's date by default

---

### Task 1: Project Scaffolding and Dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `lib/main.dart`
- Create: `lib/app.dart`

**Interfaces:**
- Consumes: nothing
- Produces: a runnable Flutter app skeleton

- [ ] **Step 1: Create Flutter project**

Run: `flutter create --org com.persist .` in the project directory (from within `persistence_app/`).

- [ ] **Step 2: Update pubspec.yaml with dependencies**

Replace the dependencies section in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1
  drift: ^2.25.1
  sqlite3_flutter_libs: ^0.5.28
  path_provider: ^2.1.5
  path: ^1.9.1
  intl: ^0.20.2
  flutter_local_notifications: ^18.0.1
  table_calendar: ^3.1.3
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
  drift_dev: ^2.25.2
  build_runner: ^2.4.14
```

Then create `analysis_options.yaml`:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    avoid_print: true
```

- [ ] **Step 3: Write main.dart entry point**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: DailyTrackerApp()));
}
```

- [ ] **Step 4: Write app.dart**

```dart
import 'package:flutter/material.dart';
import 'pages/home_page.dart';
import 'pages/timeline_page.dart';
import 'pages/diary_page.dart';
import 'pages/reminders_page.dart';
import 'pages/settings_page.dart';
import 'widgets/bottom_nav.dart';

class DailyTrackerApp extends StatelessWidget {
  const DailyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日常追蹤',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final _pages = const [
    HomePage(),
    TimelinePage(),
    DiaryPage(),
    RemindersPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNav(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
      ),
    );
  }
}
```

- [ ] **Step 5: Run `flutter pub get` to verify dependencies**

Run: `flutter pub get`

Expected: all packages resolve successfully.

---

### Task 2: Database Tables and Models

**Files:**
- Create: `lib/database/tables.dart`
- Create: `lib/database/database.dart`
- Create: `lib/models/check_in_category.dart`
- Create: `lib/models/check_in_record.dart`
- Create: `lib/models/diary_entry.dart`
- Create: `lib/models/reminder.dart`

**Interfaces:**
- Consumes: nothing
- Produces: Database class with all tables, model classes with `toJson`/`fromJson`

- [ ] **Step 1: Write tables.dart**

```dart
import 'package:drift/drift.dart';

class CheckInCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get emoji => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
}

class CheckInRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().references(CheckInCategories, #id)();
  TextColumn get date => text()(); // ISO format: yyyy-MM-dd
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
}

class DiaryEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get date => text()(); // ISO format: yyyy-MM-dd HH:mm:ss
  TextColumn get content => text()();
  IntColumn get checkInRecordId => integer().nullable().references(CheckInRecords, #id)();
}

class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get dateTime => text()(); // ISO format: yyyy-MM-dd HH:mm:ss
  IntColumn get categoryId => integer().nullable().references(CheckInCategories, #id)();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
}
```

- [ ] **Step 2: Write database.dart**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(tables: [
  CheckInCategories,
  CheckInRecords,
  DiaryEntries,
  Reminders,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'daily_tracker.db'));
    return NativeDatabase(file);
  });
}
```

- [ ] **Step 3: Run build_runner to generate database.g.dart**

Run: `dart run build_runner build`

Expected: `database.g.dart` is generated successfully.

- [ ] **Step 4: Write check_in_category.dart model**

```dart
class CheckInCategory {
  final int id;
  final String name;
  final String emoji;
  final bool isDefault;

  const CheckInCategory({
    required this.id,
    required this.name,
    required this.emoji,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'emoji': emoji,
    'isDefault': isDefault,
  };

  factory CheckInCategory.fromJson(Map<String, dynamic> json) => CheckInCategory(
    id: json['id'] as int,
    name: json['name'] as String,
    emoji: json['emoji'] as String,
    isDefault: json['isDefault'] as bool? ?? false,
  );
}
```

- [ ] **Step 5: Write check_in_record.dart model**

```dart
class CheckInRecord {
  final int id;
  final int categoryId;
  final String date;
  final bool isCompleted;
  final String? note;

  const CheckInRecord({
    required this.id,
    required this.categoryId,
    required this.date,
    this.isCompleted = false,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'categoryId': categoryId,
    'date': date,
    'isCompleted': isCompleted,
    'note': note,
  };

  factory CheckInRecord.fromJson(Map<String, dynamic> json) => CheckInRecord(
    id: json['id'] as int,
    categoryId: json['categoryId'] as int,
    date: json['date'] as String,
    isCompleted: json['isCompleted'] as bool? ?? false,
    note: json['note'] as String?,
  );
}
```

- [ ] **Step 6: Write diary_entry.dart model**

```dart
class DiaryEntry {
  final int id;
  final String date;
  final String content;
  final int? checkInRecordId;

  const DiaryEntry({
    required this.id,
    required this.date,
    required this.content,
    this.checkInRecordId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'content': content,
    'checkInRecordId': checkInRecordId,
  };

  factory DiaryEntry.fromJson(Map<String, dynamic> json) => DiaryEntry(
    id: json['id'] as int,
    date: json['date'] as String,
    content: json['content'] as String,
    checkInRecordId: json['checkInRecordId'] as int?,
  );
}
```

- [ ] **Step 7: Write reminder.dart model**

```dart
class Reminder {
  final int id;
  final String title;
  final String dateTime;
  final int? categoryId;
  final bool isCompleted;

  const Reminder({
    required this.id,
    required this.title,
    required this.dateTime,
    this.categoryId,
    this.isCompleted = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateTime': dateTime,
    'categoryId': categoryId,
    'isCompleted': isCompleted,
  };

  factory Reminder.fromJson(Map<String, dynamic> json) => Reminder(
    id: json['id'] as int,
    title: json['title'] as String,
    dateTime: json['dateTime'] as String,
    categoryId: json['categoryId'] as int?,
    isCompleted: json['isCompleted'] as bool? ?? false,
  );
}
```

---

### Task 3: Database Providers + Seed Data

**Files:**
- Create: `lib/providers/database_provider.dart`
- Create: `lib/providers/check_in_provider.dart`
- Create: `lib/providers/diary_provider.dart`
- Create: `lib/providers/reminder_provider.dart`

**Interfaces:**
- Consumes: `AppDatabase` from Task 2
- Produces: Riverpod providers for all CRUD operations

- [ ] **Step 1: Write database_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});
```

- [ ] **Step 2: Write check_in_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
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
```

- [ ] **Step 3: Write diary_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../models/diary_entry.dart';
import 'database_provider.dart';

final diaryEntriesProvider = FutureProvider<List<DiaryEntry>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.diaryEntries)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  return rows.map((r) => DiaryEntry(
    id: r.id,
    date: r.date,
    content: r.content,
    checkInRecordId: r.checkInRecordId,
  )).toList();
});
```

- [ ] **Step 4: Write reminder_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../models/reminder.dart';
import 'database_provider.dart';

final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.reminders)
    ..orderBy([(t) => OrderingTerm(expression: t.dateTime, mode: OrderingMode.asc)])).get();
  return rows.map((r) => Reminder(
    id: r.id,
    title: r.title,
    dateTime: r.dateTime,
    categoryId: r.categoryId,
    isCompleted: r.isCompleted,
  )).toList();
});
```

- [ ] **Step 5: Seed default categories on first launch**

Add to `database.dart` — add a `migration` or use `beforeOpen`:

In `database.dart`, modify:

```dart
@DriftDatabase(tables: [
  CheckInCategories,
  CheckInRecords,
  DiaryEntries,
  Reminders,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

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
        isDefault: true,
      ));
    }
  }
}
```

- [ ] **Step 6: Verify build**

Run: `dart run build_runner build` to regenerate if needed, then `flutter analyze` to check for errors.

---

### Task 4: Bottom Navigation Widget

**Files:**
- Create: `lib/widgets/bottom_nav.dart`

**Interfaces:**
- Consumes: `currentIndex` + `onTap` callback
- Produces: reusable bottom nav bar

- [ ] **Step 1: Write bottom_nav.dart**

```dart
import 'package:flutter/material.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.today), label: '首頁'),
        NavigationDestination(icon: Icon(Icons.timeline), label: '時間軸'),
        NavigationDestination(icon: Icon(Icons.book), label: '日記'),
        NavigationDestination(icon: Icon(Icons.notifications), label: '提醒'),
        NavigationDestination(icon: Icon(Icons.settings), label: '設定'),
      ],
    );
  }
}
```

---

### Task 5: Calendar Widget

**Files:**
- Create: `lib/widgets/calendar_widget.dart`

**Interfaces:**
- Consumes: marked dates, selected date, onDateSelected callback
- Produces: month calendar widget

- [ ] **Step 1: Write calendar_widget.dart**

```dart
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDateSelected;

  const CalendarWidget({
    super.key,
    required this.selectedDate,
    required this.markedDates,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime(2024),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: selectedDate,
      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) => onDateSelected(selectedDay),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        markerDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.secondary,
          shape: BoxShape.circle,
        ),
      ),
      eventLoader: (day) {
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final dateOnly = DateTime(day.year, day.month, day.day);
        return markedDates.contains(dateOnly) ? [true] : [];
      },
      locale: 'zh-TW',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
    );
  }
}
```

---

### Task 6: Home Page (Calendar + Check-in List)

**Files:**
- Create: `lib/pages/home_page.dart`
- Create: `lib/widgets/check_in_tile.dart`
- Create: `lib/widgets/check_in_dialog.dart`
- Create: `lib/pages/home_page_controller.dart` (for add/update/delete operations)

**Interfaces:**
- Consumes: `categoriesProvider`, `checkInRecordsForDateProvider`, `checkInRecordDatesProvider`
- Produces: working home page with calendar and check-in list

- [ ] **Step 1: Write check_in_tile.dart**

```dart
import 'package:flutter/material.dart';
import '../models/check_in_category.dart';

class CheckInTile extends StatelessWidget {
  final CheckInCategory category;
  final bool isCompleted;
  final String? note;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onAddNote;

  const CheckInTile({
    super.key,
    required this.category,
    required this.isCompleted,
    this.note,
    required this.onToggle,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: Text('${category.emoji} ${category.name}'),
      subtitle: note != null ? Text(note!, style: const TextStyle(fontSize: 13)) : null,
      value: isCompleted,
      onChanged: onToggle,
      secondary: note == null
          ? IconButton(icon: const Icon(Icons.edit_note, size: 20), onPressed: onAddNote)
          : null,
    );
  }
}
```

- [ ] **Step 2: Write check_in_dialog.dart**

```dart
import 'package:flutter/material.dart';

class CheckInNoteDialog extends StatefulWidget {
  final String? initialNote;
  const CheckInNoteDialog({super.key, this.initialNote});

  @override
  State<CheckInNoteDialog> createState() => _CheckInNoteDialogState();
}

class _CheckInNoteDialogState extends State<CheckInNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('備註'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(hintText: '寫點什麼...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Write home_page.dart**

```dart
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
        isCompleted: true,
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
```

- [ ] **Step 4: Run `flutter analyze` and fix any issues**

Run: `flutter analyze`

Expected: no errors.

---

### Task 7: Reminders Page

**Files:**
- Create: `lib/pages/reminders_page.dart`
- Modify: `lib/providers/reminder_provider.dart` (add CRUD methods)

- [ ] **Step 1: Add CRUD methods to reminder_provider.dart**

Replace the file content:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../models/reminder.dart';
import 'database_provider.dart';

final remindersProvider = FutureProvider<List<Reminder>>((ref) async {
  final db = ref.read(databaseProvider);
  final rows = await (db.select(db.reminders)
    ..orderBy([(t) => OrderingTerm(expression: t.dateTime, mode: OrderingMode.asc)])).get();
  return rows.map((r) => Reminder(
    id: r.id,
    title: r.title,
    dateTime: r.dateTime,
    categoryId: r.categoryId,
    isCompleted: r.isCompleted,
  )).toList();
});

final reminderNotifierProvider = Provider<ReminderNotifier>((ref) {
  return ReminderNotifier(ref);
});

class ReminderNotifier {
  final Ref _ref;
  ReminderNotifier(this._ref);

  Future<void> addReminder(RemindersCompanion companion) async {
    final db = _ref.read(databaseProvider);
    await db.into(db.reminders).insert(companion);
    _ref.invalidate(remindersProvider);
  }

  Future<void> toggleReminder(int id, bool completed) async {
    final db = _ref.read(databaseProvider);
    await (db.update(db.reminders)
      ..where((t) => t.id.equals(id))).write(RemindersCompanion(isCompleted: Value(completed)));
    _ref.invalidate(remindersProvider);
  }

  Future<void> deleteReminder(int id) async {
    final db = _ref.read(databaseProvider);
    await (db.delete(db.reminders)..where((t) => t.id.equals(id))).go();
    _ref.invalidate(remindersProvider);
  }
}
```

- [ ] **Step 2: Write reminders_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/check_in_provider.dart';
import '../models/reminder.dart';

class RemindersPage extends ConsumerWidget {
  const RemindersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remindersAsync = ref.watch(remindersProvider);
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('提醒')),
      body: remindersAsync.when(
        data: (reminders) => reminders.isEmpty
            ? const Center(child: Text('尚無提醒'))
            : ListView.builder(
                itemCount: reminders.length,
                itemBuilder: (_, i) => _ReminderTile(reminder: reminders[i]),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('載入失敗')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _AddReminderSheet(),
    );
  }
}

class _ReminderTile extends ConsumerWidget {
  final Reminder reminder;
  const _ReminderTile({required this.reminder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dt = DateTime.parse(reminder.dateTime);
    return ListTile(
      title: Text(reminder.title, decoration: reminder.isCompleted ? TextDecoration.lineThrough : null),
      subtitle: Text(DateFormat('M/d HH:mm', 'zh-TW').format(dt)),
      leading: Checkbox(
        value: reminder.isCompleted,
        onChanged: (v) => ref.read(reminderNotifierProvider).toggleReminder(reminder.id, v ?? false),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () => ref.read(reminderNotifierProvider).deleteReminder(reminder.id),
      ),
    );
  }
}

class _AddReminderSheet extends ConsumerStatefulWidget {
  @override
  ConsumerState<_AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends ConsumerState<_AddReminderSheet> {
  final _titleController = TextEditingController();
  DateTime _dateTime = DateTime.now().add(const Duration(hours: 1));
  int? _selectedCategoryId;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16, right: 16, top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('新增提醒', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: '標題', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(_dateTime)),
            leading: const Icon(Icons.access_time),
            onTap: () async {
              final dt = await showDatePicker(
                context: context,
                initialDate: _dateTime,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (dt != null) {
                final tm = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_dateTime));
                if (tm != null) {
                  setState(() => _dateTime = DateTime(dt.year, dt.month, dt.day, tm.hour, tm.minute));
                }
              }
            },
          ),
          categoriesAsync.when(
            data: (cats) => DropdownButtonFormField<int?>(
              value: _selectedCategoryId,
              decoration: const InputDecoration(labelText: '綁定打卡項目（可選）'),
              items: [
                const DropdownMenuItem(value: null, child: Text('不綁定')),
                ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text('${c.emoji} ${c.name}'))),
              ],
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _titleController.text.trim().isEmpty ? null : () {
              ref.read(reminderNotifierProvider).addReminder(RemindersCompanion.insert(
                title: _titleController.text.trim(),
                dateTime: _dateTime.toIso8601String(),
                categoryId: _selectedCategoryId != null ? Value(_selectedCategoryId!) : Value.absent(),
              ));
              Navigator.pop(context);
            },
            child: const Text('新增'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

---

### Task 8: Diary Page (List, Detail, Edit)

**Files:**
- Create: `lib/pages/diary_page.dart`
- Create: `lib/pages/diary_detail_page.dart`
- Create: `lib/pages/diary_edit_page.dart`

- [ ] **Step 1: Write diary_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/diary_provider.dart';
import 'diary_detail_page.dart';
import 'diary_edit_page.dart';

class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diaryAsync = ref.watch(diaryEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('日記')),
      body: diaryAsync.when(
        data: (entries) => entries.isEmpty
            ? const Center(child: Text('尚無日記'))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final dt = DateTime.parse(entry.date);
                  return ListTile(
                    title: Text(
                      entry.content.split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(dt)),
                    trailing: entry.checkInRecordId != null ? const Icon(Icons.check_circle_outline, size: 16) : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DiaryDetailPage(entry: entry),
                    )),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('載入失敗')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const DiaryEditPage(),
        )),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
```

- [ ] **Step 2: Write diary_detail_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/diary_entry.dart';

class DiaryDetailPage extends StatelessWidget {
  final DiaryEntry entry;
  const DiaryDetailPage({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.parse(entry.date);
    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(dt))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Text(entry.content, style: const TextStyle(fontSize: 16, height: 1.6)),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Write diary_edit_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/diary_provider.dart';

class DiaryEditPage extends ConsumerStatefulWidget {
  const DiaryEditPage({super.key});

  @override
  ConsumerState<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends ConsumerState<DiaryEditPage> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('寫日記'),
        actions: [
          TextButton(
            onPressed: _controller.text.trim().isEmpty ? null : _save,
            child: const Text('儲存'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          decoration: const InputDecoration(
            hintText: '今天發生了什麼事...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
      date: DateTime.now().toIso8601String(),
      content: _controller.text.trim(),
    ));
    ref.invalidate(diaryEntriesProvider);
    Navigator.pop(context);
  }
}
```

---

### Task 9: Timeline Page

**Files:**
- Create: `lib/pages/timeline_page.dart`

- [ ] **Step 1: Write timeline_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/check_in_provider.dart';
import '../providers/diary_provider.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';

final timelineProvider = FutureProvider<List<_TimelineItem>>((ref) async {
  final db = ref.read(databaseProvider);
  final checkIns = await (db.select(db.checkInRecords)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  final diaries = await (db.select(db.diaryEntries)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  final categories = await db.select(db.checkInCategories).get();
  final catMap = {for (final c in categories) c.id: c};

  final items = <_TimelineItem>[];
  for (final r in checkIns) {
    final cat = catMap[r.categoryId];
    items.add(_TimelineItem(
      date: r.date,
      type: 'checkin',
      title: cat != null ? '${cat.emoji} ${cat.name}' : '未知',
      subtitle: r.note,
      isCompleted: r.isCompleted,
    ));
  }
  for (final d in diaries) {
    items.add(_TimelineItem(
      date: d.date.substring(0, 10),
      type: 'diary',
      title: '📝 日記',
      subtitle: d.content.split('\n').first,
    ));
  }
  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});

class _TimelineItem {
  final String date;
  final String type;
  final String title;
  final String? subtitle;
  final bool isCompleted;
  _TimelineItem({required this.date, required this.type, required this.title, this.subtitle, this.isCompleted = false});
}

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(timelineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('時間軸')),
      body: timelineAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('尚無紀錄'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final item = items[i];
                  return ListTile(
                    leading: Icon(
                      item.type == 'checkin' ? Icons.check_circle : Icons.book,
                      color: item.type == 'checkin'
                          ? (item.isCompleted ? Colors.green : Colors.grey)
                          : Colors.blue,
                    ),
                    title: Text(item.title),
                    subtitle: Text('${item.date}${item.subtitle != null ? ' - ${item.subtitle}' : ''}'),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => const Center(child: Text('載入失敗')),
      ),
    );
  }
}
```

---

### Task 10: Settings Page (Categories + Backup)

**Files:**
- Create: `lib/pages/settings_page.dart`

- [ ] **Step 1: Write settings_page.dart**

```dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../providers/database_provider.dart';
import '../providers/check_in_provider.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/diary_entry.dart';
import '../models/reminder.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          const _SectionHeader(title: '打卡項目'),
          categoriesAsync.when(
            data: (cats) => Column(
              children: [
                ...cats.map((cat) => ListTile(
                  leading: Text(cat.emoji, style: const TextStyle(fontSize: 24)),
                  title: Text(cat.name),
                  subtitle: cat.isDefault ? const Text('預設') : null,
                  trailing: cat.isDefault ? null : IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteCategory(ref, cat.id),
                  ),
                )),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Center(child: Text('載入失敗')),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('新增項目'),
            onTap: () => _showAddCategoryDialog(context, ref),
          ),
          const Divider(),
          const _SectionHeader(title: '資料管理'),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('匯出備份'),
            onTap: () => _exportData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('匯入備份'),
            onTap: () => _importData(context, ref),
          ),
          const Divider(),
          const _SectionHeader(title: '帳號'),
          ListTile(
            leading: const Icon(Icons.login),
            title: const Text('登入 Google 帳號'),
            subtitle: const Text('即將推出'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Future<void> _deleteCategory(WidgetRef ref, int id) async {
    final db = ref.read(databaseProvider);
    await (db.delete(db.checkInRecords)..where((t) => t.categoryId.equals(id))).go();
    await (db.delete(db.checkInCategories)..where((t) => t.id.equals(id))).go();
    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
  }

  void _showAddCategoryDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    String emoji = '📌';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('新增打卡項目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: '名稱', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Text('選擇圖示：$emoji', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: '🏃📚💧🧘💪🎵✍️🍎☕🎮📝🛌🎯🌈'.split('').map((e) => GestureDetector(
                  onTap: () => setDialogState(() => emoji = e),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: emoji == e ? Colors.teal : Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 24)),
                  ),
                )).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: nameController.text.trim().isEmpty ? null : () async {
                final db = ref.read(databaseProvider);
                await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
                  name: nameController.text.trim(),
                  emoji: emoji,
                ));
                ref.invalidate(categoriesProvider);
                Navigator.pop(ctx);
              },
              child: const Text('新增'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final cats = await db.select(db.checkInCategories).get();
    final records = await db.select(db.checkInRecords).get();
    final diaries = await db.select(db.diaryEntries).get();
    final reminders = await db.select(db.reminders).get();

    final data = {
      'version': 1,
      'exportDate': DateTime.now().toIso8601String(),
      'categories': cats.map((r) => CheckInCategory(id: r.id, name: r.name, emoji: r.emoji, isDefault: r.isDefault).toJson()).toList(),
      'records': records.map((r) => CheckInRecord(id: r.id, categoryId: r.categoryId, date: r.date, isCompleted: r.isCompleted, note: r.note).toJson()).toList(),
      'diaries': diaries.map((r) => DiaryEntry(id: r.id, date: r.date, content: r.content, checkInRecordId: r.checkInRecordId).toJson()).toList(),
      'reminders': reminders.map((r) => Reminder(id: r.id, title: r.title, dateTime: r.dateTime, categoryId: r.categoryId, isCompleted: r.isCompleted).toJson()).toList(),
    };

    final dir = Directory('/tmp');
    final file = File('${dir.path}/daily_tracker_backup.json');
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已匯出到 ${file.path}')),
      );
    }
  }

  Future<void> _importData(BuildContext context, WidgetRef ref) async {
    final dir = Directory('/tmp');
    final file = File('${dir.path}/daily_tracker_backup.json');
    if (!await file.exists()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('找不到備份檔案')),
      );
      return;
    }

    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final db = ref.read(databaseProvider);

    // Clear existing data
    await db.delete(db.reminders).go();
    await db.delete(db.diaryEntries).go();
    await db.delete(db.checkInRecords).go();
    await db.delete(db.checkInCategories).go();

    // Import
    for (final c in json['categories'] as List) {
      final m = CheckInCategory.fromJson(c as Map<String, dynamic>);
      await db.into(db.checkInCategories).insert(CheckInCategoriesCompanion.insert(
        name: m.name, emoji: m.emoji, isDefault: m.isDefault,
      ));
    }
    for (final r in json['records'] as List) {
      final m = CheckInRecord.fromJson(r as Map<String, dynamic>);
      await db.into(db.checkInRecords).insert(CheckInRecordsCompanion.insert(
        categoryId: m.categoryId, date: m.date, isCompleted: m.isCompleted, note: Value(m.note),
      ));
    }
    for (final d in json['diaries'] as List) {
      final m = DiaryEntry.fromJson(d as Map<String, dynamic>);
      await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
        date: m.date, content: m.content, checkInRecordId: Value(m.checkInRecordId),
      ));
    }
    for (final r in json['reminders'] as List) {
      final m = Reminder.fromJson(r as Map<String, dynamic>);
      await db.into(db.reminders).insert(RemindersCompanion.insert(
        title: m.title, dateTime: m.dateTime, isCompleted: m.isCompleted,
        categoryId: m.categoryId != null ? Value(m.categoryId!) : Value.absent(),
      ));
    }

    ref.invalidate(categoriesProvider);
    ref.invalidate(checkInRecordDatesProvider);
    ref.invalidate(diaryEntriesProvider);
    ref.invalidate(remindersProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('匯入完成')),
      );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(title, style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      )),
    );
  }
}
```

---

### Task 11: Final Integration Test

**Files:**
- All files from previous tasks

- [ ] **Step 1: Run `flutter analyze`**

Run: `flutter analyze`

Expected: no errors or warnings.

- [ ] **Step 2: Run `flutter run -d chrome` to verify app launches**

Run: `flutter run -d chrome`

Expected: app opens in Chrome with 5 bottom tabs, home page shows calendar with today selected and 4 default check-in categories.

- [ ] **Step 3: Manual smoke test**
  - Verify 4 default categories appear (運動 🏃, 閱讀 📚, 喝水 💧, 冥想 🧘)
  - Toggle a checkbox → verify it stays checked on page refresh
  - Add a note to a check-in → verify note appears
  - Switch to a different date → tap back to today → verify data persists
  - Go to 提醒 tab → add a reminder → verify it appears in list
  - Go to 日記 tab → write a diary entry → verify it appears
  - Go to 時間軸 tab → verify check-ins and diaries appear mixed
  - Go to 設定 → add a new category → verify it appears on home page
  - Export → verify backup file created
