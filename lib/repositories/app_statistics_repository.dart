import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_app_statistics_repository.dart';
import '../models/app_statistics.dart';

part 'app_statistics_repository.g.dart';

@riverpod
class AppStatisticsRepository extends _$AppStatisticsRepository implements IAppStatisticsRepository {
  late final AppDatabase _db;

  @override
  Future<AppStatistics> build() {
    ref.keepAlive();
    _db = ref.read(appDatabaseProvider.notifier);
    return _getDatabaseStatistics();
  }

  @override
  Future<AppStatistics> getStatistics() => _getDatabaseStatistics();

  @override
  void clear() async {
    await _db.delete('files');
    await _db.delete('tags');
    await _db.delete('file_tags');

    state = await AsyncValue.guard(() => _getDatabaseStatistics());
  }

  Future<AppStatistics> _getDatabaseStatistics() async {
    AppStatistics databaseStatistics = AppStatistics();

    List<Map<String, dynamic>> rows = await _db.query('tags', columns: ['COUNT(*) as count']);
    databaseStatistics.tagCount = rows.first['count'];

    rows = await _db.query('files', columns: ['COUNT(*) as count']);
    databaseStatistics.fileCount = rows.first['count'];

    return databaseStatistics;
  }
}