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
      appBar: AppBar(
        title: Text(entry.title ?? DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(dt)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.title != null) ...[
                Text(entry.title!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(DateFormat('yyyy/M/d HH:mm', 'zh-TW').format(dt),
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const Divider(),
              ],
              Text(entry.content, style: const TextStyle(fontSize: 16, height: 1.6)),
            ],
          ),
        ),
      ),
    );
  }
}
