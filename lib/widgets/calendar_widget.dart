import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../l10n/locale_helpers.dart';

class CalendarWidget extends StatelessWidget {
  final DateTime selectedDate;
  final Set<DateTime> markedDates;
  final ValueChanged<DateTime> onDateSelected;
  final bool navigable;

  const CalendarWidget({
    super.key,
    required this.selectedDate,
    required this.markedDates,
    required this.onDateSelected,
    this.navigable = true,
  });

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      firstDay: DateTime(2024),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: selectedDate,
      selectedDayPredicate: (day) => isSameDay(selectedDate, day),
      onDaySelected: (selectedDay, focusedDay) => onDateSelected(selectedDay),
      // navigable=false 时首页折叠态只读当月，展开态可翻月
      pageJumpingEnabled: navigable,
      availableGestures: navigable ? AvailableGestures.all : AvailableGestures.none,
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
      locale: intlLocaleOf(context),
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
    );
  }
}
