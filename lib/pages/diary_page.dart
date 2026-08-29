import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/diary_provider.dart';
import 'diary_detail_page.dart';
import 'diary_edit_page.dart';
import '../l10n/generated/app_localizations.dart';
import '../l10n/locale_helpers.dart';

class DiaryPage extends ConsumerWidget {
  const DiaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final diaryAsync = ref.watch(diaryEntriesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.diary)),
      body: diaryAsync.when(
        data: (entries) => entries.isEmpty
            ? Center(child: Text(l10n.noDiary))
            : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final dt = DateTime.parse(entry.date);
                  return ListTile(
                    title: Text(
                      entry.content.split('\n').first,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(DateFormat('yyyy/M/d HH:mm', intlLocaleOf(context)).format(dt)),
                    trailing: entry.checkInRecordId != null ? const Icon(Icons.check_circle_outline, size: 16) : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => DiaryDetailPage(entry: entry),
                    )),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(
          builder: (_) => const DiaryEditPage(),
        )),
        child: const Icon(Icons.edit),
      ),
    );
  }
}
