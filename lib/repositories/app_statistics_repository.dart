import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/app_statistics.dart';

part 'app_statistics_repository.g.dart';

@riverpod
class AppStatisticsRepository extends _$AppStatisticsRepository {
  late AppDatabase _database;

  @override
  Future<AppStatistics> build() {
    _database = AppDatabase();

    return _getDatabaseStatistics();
  }

  void clear() async {
    _database.delete('files');
    _database.delete('tags');
    _database.delete('file_tags');

    state = await AsyncValue.guard(() => _getDatabaseStatistics());
  }

  Future<AppStatistics> _getDatabaseStatistics() async {
    AppStatistics databaseStatistics = AppStatistics();

    List<Map<String, dynamic>> rows = await _database.query('tags', columns: ['COUNT(*) as count']);
    databaseStatistics.tagCount = rows.first['count'];

    rows = await _database.query('files', columns: ['COUNT(*) as count']);
    databaseStatistics.fileCount = rows.first['count'];

    return databaseStatistics;
  }
}