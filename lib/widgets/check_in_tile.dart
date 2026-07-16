import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';

class CheckInTile extends StatelessWidget {
  final CheckInCategory category;
  final CheckInRecord? record;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onAddNote;

  const CheckInTile({
    super.key,
    required this.category,
    this.record,
    required this.onToggle,
    required this.onAddNote,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (record?.completedAt != null) {
      final dt = DateTime.parse(record!.completedAt!);
      subtitleParts.add(DateFormat('HH:mm', 'zh-TW').format(dt));
    }
    if (category.startTime != null) subtitleParts.add('⏰ ${category.startTime}');
    if (record?.note != null) subtitleParts.add(record!.note!);
    final completed = record?.isCompleted ?? false;
    return CheckboxListTile(
      title: Text('${category.emoji} ${category.name}'),
      subtitle: subtitleParts.isNotEmpty
          ? Text(subtitleParts.join(' | '), style: const TextStyle(fontSize: 13))
          : null,
      value: completed,
      onChanged: onToggle,
      secondary: record?.note == null
          ? IconButton(icon: const Icon(Icons.edit_note, size: 20), onPressed: onAddNote)
          : null,
    );
  }
}
