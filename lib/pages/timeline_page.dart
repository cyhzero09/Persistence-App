import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import 'package:drift/drift.dart';
import '../l10n/generated/app_localizations.dart';

final timelineProvider = FutureProvider<List<_TimelineItem>>((ref) async {
  final db = ref.read(databaseProvider);
  final checkIns = await (db.select(db.checkInRecords)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  final diaries = await (db.select(db.diaryEntries)
    ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])).get();
  final categories = await db.select(db.checkInCategories).get();
  final catMap = {for (final c in categories) c.id: c};

  final items = <_TimelineItem>[];
  for (final r in checkIns) {
    final cat = catMap[r.categoryId];
    items.add(_TimelineItem(
      date: r.date,
      type: 'checkin',
      title: cat != null ? '${cat.emoji} ${cat.name}' : 'unknown',
      subtitle: r.note,
      isCompleted: r.isCompleted,
    ));
  }
  for (final d in diaries) {
    items.add(_TimelineItem(
      date: d.date.substring(0, 10),
      type: 'diary',
      title: 'diary',
      subtitle: d.content.split('\n').first,
    ));
  }
  items.sort((a, b) => b.date.compareTo(a.date));
  return items;
});

class _TimelineItem {
  final String date;
  final String type;
  final String title;
  final String? subtitle;
  final bool isCompleted;
  _TimelineItem({required this.date, required this.type, required this.title, this.subtitle, this.isCompleted = false});
}

class TimelinePage extends ConsumerWidget {
  const TimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final timelineAsync = ref.watch(timelineProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.timeline)),
      body: timelineAsync.when(
        data: (items) => items.isEmpty
            ? Center(child: Text(l10n.noRecords))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(timelineProvider.future),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    final title = item.title == 'diary'
                        ? '📝 ${l10n.diaryEntry}'
                        : (item.title == 'unknown' ? l10n.unknown : item.title);
                    return ListTile(
                      leading: Icon(
                        item.type == 'checkin' ? Icons.check_circle : Icons.book,
                        color: item.type == 'checkin'
                            ? (item.isCompleted ? Colors.green : Colors.grey)
                            : Colors.blue,
                      ),
                      title: Text(title),
                      subtitle: Text('${item.date}${item.subtitle != null ? ' - ${item.subtitle}' : ''}'),
                    );
                  },
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
      ),
    );
  }
}
