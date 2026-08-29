import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

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
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.note),
      content: TextField(
        controller: _controller,
        maxLines: 3,
        decoration: InputDecoration(hintText: l10n.noteHint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
