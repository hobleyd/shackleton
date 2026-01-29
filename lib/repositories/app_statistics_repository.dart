import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/app_statistics.dart';

part 'app_statistics_repository.g.dart';

@riverpod
class AppStatisticsRepository extends _$AppStatisticsRepository {
  @override
  Future<AppStatistics> build() {
    return _getDatabaseStatistics();
  }

  void clear() async {
    ref.read(appDatabaseProvider.notifier).delete('files');
    ref.read(appDatabaseProvider.notifier).delete('tags');
    ref.read(appDatabaseProvider.notifier).delete('file_tags');

    state = await AsyncValue.guard(() => _getDatabaseStatistics());
  }

  Future<AppStatistics> _getDatabaseStatistics() async {
    AppStatistics databaseStatistics = AppStatistics();

    List<Map<String, dynamic>> rows = await ref.read(appDatabaseProvider.notifier).query('tags', columns: ['COUNT(*) as count']);
    databaseStatistics.tagCount = rows.first['count'];

    rows = await ref.read(appDatabaseProvider.notifier).query('files', columns: ['COUNT(*) as count']);
    databaseStatistics.fileCount = rows.first['count'];

    return databaseStatistics;
  }
}