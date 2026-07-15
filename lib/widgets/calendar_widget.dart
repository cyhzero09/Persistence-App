import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

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
        final dateOnly = DateTime(day.year, day.month, day.day);
        return markedDates.contains(dateOnly) ? [true] : [];
      },
      locale: 'zh-TW',
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
    );
  }
}
