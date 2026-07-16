import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDateSelected;

  const WeekCalendar({
    super.key,
    required this.selectedDate,
    required this.markedDates,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final monday = _mondayOf(selectedDate);

    return Column(
      children: [
        _buildWeekRow(context, monday.subtract(const Duration(days: 7)), todayDate),
        const SizedBox(height: 2),
        _buildWeekRow(context, monday, todayDate),
        const SizedBox(height: 2),
        _buildWeekRow(context, monday.add(const Duration(days: 7)), todayDate),
      ],
    );
  }

  DateTime _mondayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Widget _buildWeekRow(BuildContext context, DateTime weekStart, DateTime todayDate) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: days.map((day) {
          final isSelected = DateTime(day.year, day.month, day.day) == DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final isToday = DateTime(day.year, day.month, day.day) == todayDate;
          final hasMark = markedDates.contains(DateTime(day.year, day.month, day.day));
          return Expanded(
            child: GestureDetector(
              onTap: () => onDateSelected(day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      DateFormat('E', 'zh-TW').format(day),
                      style: TextStyle(
                        fontSize: 11,
                        color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null,
                      ),
                    ),
                    if (hasMark)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 7),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
