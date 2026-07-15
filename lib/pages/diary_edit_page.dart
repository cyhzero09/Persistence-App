import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    if (!mounted) return;
    Navigator.pop(context);
  }
}
