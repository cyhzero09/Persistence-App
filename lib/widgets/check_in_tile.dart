import 'package:flutter/material.dart';
import '../models/check_in_category.dart';
import '../models/check_in_record.dart';

class CheckInTile extends StatelessWidget {
  final CheckInCategory category;
  final CheckInRecord? record;
  final ValueChanged<bool?> onToggle;
  final VoidCallback onAddNote;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const CheckInTile({
    super.key,
    required this.category,
    this.record,
    required this.onToggle,
    required this.onAddNote,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitleParts = <String>[];
    if (record?.completedAt != null) {
      final parts = record!.completedAt!.split(' ');
      if (parts.length >= 2) {
        subtitleParts.add(parts[1].substring(0, 5));
      } else if (parts[0].contains('T')) {
        subtitleParts.add(parts[0].split('T')[1].substring(0, 5));
      }
    }
    if (category.startTime != null) subtitleParts.add('⏰ ${category.startTime}');
    if (record?.note != null) subtitleParts.add(record!.note!);
    final completed = record?.isCompleted ?? false;
    return ListTile(
      leading: Checkbox(value: completed, onChanged: onToggle),
      title: Text('${category.emoji} ${category.name}'),
      subtitle: subtitleParts.isNotEmpty
          ? Text(subtitleParts.join(' | '), style: const TextStyle(fontSize: 13))
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: Icon(Icons.edit_note, size: 20,
            color: (record?.note != null) ? Theme.of(context).colorScheme.primary : null,
          ), onPressed: onAddNote),
          if (onEdit != null)
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit),
          if (onDelete != null)
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete),
        ],
      ),
      onTap: onTap,
    );
  }
}
