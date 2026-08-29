import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

/// 弹出删除确认对话框，返回用户是否确认删除。
Future<bool> confirmDelete(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.deleteConfirmTitle),
      content: Text(l10n.deleteConfirmMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
