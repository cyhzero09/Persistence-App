import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';
import '../models/reminder.dart';
import '../providers/check_in_provider.dart';
import '../providers/reminder_provider.dart';

class CategoryDetailPage extends ConsumerStatefulWidget {
  final CheckInCategory category;
  const CategoryDetailPage({super.key, required this.category});

  @override
  ConsumerState<CategoryDetailPage> createState() => _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(checkInRecordsForCategoryProvider(widget.category.id));
    final remindersAsync = ref.watch(remindersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.category.emoji} ${widget.category.name}'),
      ),
      body: recordsAsync.when(
        data: (records) {
          final datesWithRecords = records
            .map((r) => DateTime.parse(r.date))
            .toSet();
          final markedDates = datesWithRecords
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet();

          return remindersAsync.when(
            data: (reminders) => Column(
              children: [
                _buildHeader(context, reminders),
                const Divider(),
                _buildCalendar(markedDates, records),
                const Divider(),
                _buildSelectedDateDetail(records),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => Column(
              children: [
                _buildCalendar(markedDates, records),
                const Divider(),
                _buildSelectedDateDetail(records),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, List<Reminder> reminders) {
    final linkedReminder = reminders.where((r) => r.categoryId == widget.category.id).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(widget.category.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.category.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    if (widget.category.description != null && widget.category.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(widget.category.description!,
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (linkedReminder.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: linkedReminder.map((r) {
                  final parts = <String>[];
                  if (r.isRepeating) {
                    parts.add('每週 ${r.repeatWeekdays!.split(',').map((s) => ['一','二','三','四','五','六','日'][int.parse(s)]).join('、')}');
                    if (r.repeatEndDate != null) {
                      parts.add('至 ${r.repeatEndDate}');
                    } else {
                      parts.add('至永遠');
                    }
                  } else {
                    parts.add(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(DateTime.parse(r.dateTime)));
                  }
                  return Row(
                    children: [
                      Icon(Icons.notifications_outlined, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(parts.join('，'), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar(Set<DateTime> markedDates, List<CheckInRecord> records) {
    return TableCalendar(
      firstDay: DateTime(2024),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: _selectedDate,
      selectedDayPredicate: (day) => isSameDay(_selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) => setState(() => _selectedDate = selectedDay),
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
        final dateOnly = DateTime(day.year, day.month, day.day);
        return markedDates.contains(dateOnly) ? [true] : [];
      },
      locale: 'zh-TW',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
    );
  }

  Widget _buildSelectedDateDetail(List<CheckInRecord> records) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final dayRecords = records.where((r) => r.date == dateStr).toList();

    if (dayRecords.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('此日無打卡紀錄'),
      );
    }

    return Expanded(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: dayRecords.map((r) {
          DateTime? time;
          try {
            time = DateTime.parse(r.date);
          } catch (_) {}
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (time != null)
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(DateFormat('HH:mm', 'zh-TW').format(time),
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  if (r.note != null && r.note!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('備註：${r.note}'),
                  ],
                  if ((r.note == null || r.note!.isEmpty) && time == null)
                    const Text('已打卡'),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
