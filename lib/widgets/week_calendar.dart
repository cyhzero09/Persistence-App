import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDateSelected;
  final bool showFullMonth;

  const WeekCalendar({
    super.key,
    required this.selectedDate,
    required this.markedDates,
    required this.onDateSelected,
    this.showFullMonth = false,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    if (showFullMonth) {
      final firstOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
      final startSunday = _sundayOf(firstOfMonth);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Row(
              children: List.generate(7, (i) => Expanded(
                child: Center(
                  child: Text(
                    ['日','一','二','三','四','五','六'][i],
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )),
            ),
          ),
          ...List.generate(6, (week) => _buildWeekRow(
            context, startSunday.add(Duration(days: week * 7)), todayDate,
            month: selectedDate.month,
          )),
        ],
      );
    }

    final sunday = _sundayOf(today);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildWeekRow(context, sunday.subtract(const Duration(days: 7)), todayDate),
        const SizedBox(height: 2),
        _buildWeekRow(context, sunday, todayDate),
        const SizedBox(height: 2),
        _buildWeekRow(context, sunday.add(const Duration(days: 7)), todayDate),
      ],
    );
  }

  DateTime _sundayOf(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return d.subtract(Duration(days: d.weekday % 7));
  }

  Widget _buildWeekRow(BuildContext context, DateTime weekStart, DateTime todayDate, {int? month}) {
    final days = List.generate(7, (i) => weekStart.add(Duration(days: i)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: days.map((day) {
          final isSelected = DateTime(day.year, day.month, day.day) == DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
          final isToday = DateTime(day.year, day.month, day.day) == todayDate;
          final hasMark = markedDates.contains(DateTime(day.year, day.month, day.day));
          final isOtherMonth = month != null && day.month != month;
          return Expanded(
            child: GestureDetector(
              onTap: () => onDateSelected(day),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    if (showFullMonth)
                      Text(
                        DateFormat('E', 'zh-TW').format(day),
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                        color: isOtherMonth
                            ? Theme.of(context).colorScheme.outline
                            : (isSelected ? Theme.of(context).colorScheme.onPrimaryContainer : null),
                      ),
                    ),
                    if (hasMark)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          shape: BoxShape.circle,
                        ),
                      )
                    else
                      const SizedBox(height: 6),
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
