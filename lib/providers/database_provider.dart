import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../database/executor.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase(createExecutor());
});
