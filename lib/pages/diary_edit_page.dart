import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' show Value;
import '../database/database.dart' hide DiaryEntry;
import '../providers/database_provider.dart';
import '../providers/diary_provider.dart';
import '../models/diary_entry.dart';

class DiaryEditPage extends ConsumerStatefulWidget {
  final DiaryEntry? entry;
  final DateTime? initialDate;

  const DiaryEditPage({super.key, this.entry, this.initialDate});

  @override
  ConsumerState<DiaryEditPage> createState() => _DiaryEditPageState();
}

class _DiaryEditPageState extends ConsumerState<DiaryEditPage> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  late DateTime _diaryDate;
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    if (widget.entry != null) {
      _titleController.text = widget.entry!.title ?? '';
      _contentController.text = widget.entry!.content;
      _diaryDate = DateTime.parse(widget.entry!.date);
      _hasContent = widget.entry!.content.trim().isNotEmpty;
    } else {
      _diaryDate = widget.initialDate ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy/M/d', 'zh-TW').format(_diaryDate);
    final isEditing = widget.entry != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '編輯日記' : '寫日記'),
        actions: [
          TextButton(
            onPressed: _hasContent ? _save : null,
            child: Text(isEditing ? '儲存' : '新增'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              readOnly: true,
              controller: TextEditingController(text: dateStr),
              decoration: const InputDecoration(
                labelText: '日期 *',
                border: OutlineInputBorder(),
                suffixIcon: Icon(Icons.calendar_today),
              ),
              onTap: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: _diaryDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (dt != null) setState(() => _diaryDate = dt);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '標題（可選）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: '今天發生了什麼事...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _hasContent = v.trim().isNotEmpty),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final db = ref.read(databaseProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_diaryDate);
    final now = DateTime.now();
    final dateTimeStr = '$dateStr ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:00';

    if (widget.entry != null) {
      await (db.update(db.diaryEntries)
        ..where((t) => t.id.equals(widget.entry!.id)))
        .write(DiaryEntriesCompanion(
          date: Value(dateTimeStr),
          title: _titleController.text.trim().isNotEmpty ? Value(_titleController.text.trim()) : const Value.absent(),
          content: Value(_contentController.text.trim()),
        ));
    } else {
      await db.into(db.diaryEntries).insert(DiaryEntriesCompanion.insert(
        date: dateTimeStr,
        title: _titleController.text.trim().isNotEmpty ? Value(_titleController.text.trim()) : const Value.absent(),
        content: _contentController.text.trim(),
      ));
    }
    ref.invalidate(diaryEntriesProvider);
    if (!mounted) return;
    Navigator.pop(context);
  }
}
