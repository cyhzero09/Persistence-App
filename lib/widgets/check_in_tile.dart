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
    final subtitleParts = <String>[];
    if (category.startTime != null) subtitleParts.add('⏰ ${category.startTime}');
    if (note != null) subtitleParts.add(note!);
    return CheckboxListTile(
      title: Text('${category.emoji} ${category.name}'),
      subtitle: subtitleParts.isNotEmpty
          ? Text(subtitleParts.join('\n'), style: const TextStyle(fontSize: 13))
          : null,
      value: isCompleted,
      onChanged: onToggle,
      secondary: note == null
          ? IconButton(icon: const Icon(Icons.edit_note, size: 20), onPressed: onAddNote)
          : null,
    );
  }
}
