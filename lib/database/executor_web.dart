import 'package:drift/drift.dart';
import 'package:drift/web.dart';

QueryExecutor createExecutor() {
  return LazyDatabase(() async {
    return WebDatabase('daily_tracker');
  });
}
