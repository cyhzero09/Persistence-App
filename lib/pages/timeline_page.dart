import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import 'package:drift/drift.dart';

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
      title: cat != null ? '${cat.emoji} ${cat.name}' : '未知',
      subtitle: r.note,
      isCompleted: r.isCompleted,
    ));
  }
  for (final d in diaries) {
    items.add(_TimelineItem(
      date: d.date.substring(0, 10),
      type: 'diary',
      title: '📝 日記',
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
    final timelineAsync = ref.watch(timelineProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('時間軸')),
      body: timelineAsync.when(
        data: (items) => items.isEmpty
            ? const Center(child: Text('尚無紀錄'))
            : RefreshIndicator(
                onRefresh: () => ref.refresh(timelineProvider.future),
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      leading: Icon(
                        item.type == 'checkin' ? Icons.check_circle : Icons.book,
                        color: item.type == 'checkin'
                            ? (item.isCompleted ? Colors.green : Colors.grey)
                            : Colors.blue,
                      ),
                      title: Text(item.title),
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
