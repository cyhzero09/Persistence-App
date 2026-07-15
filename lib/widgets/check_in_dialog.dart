import 'package:flutter/material.dart';

class CheckInNoteDialog extends StatefulWidget {
  final String? initialNote;
  const CheckInNoteDialog({super.key, this.initialNote});

  @override
  State<CheckInNoteDialog> createState() => _CheckInNoteDialogState();
}

class _CheckInNoteDialogState extends State<CheckInNoteDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialNote);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('備註'),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: const InputDecoration(hintText: '寫點什麼...'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
