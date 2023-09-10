import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../misc/utils.dart';
import '../models/app_settings.dart';

part 'app_settings_repository.g.dart';

@riverpod
class AppSettingsRepository extends _$AppSettingsRepository {
  late AppDatabase _database;

  static const String tableName = 'app_settings';
  static const String createAppSettings = '''
        create table if not exists $tableName(
          id                integer primary key, 
          libraryPath       text    not null,
          fontSize          int     not null,
          );
          ''';

  @override
  Future<AppSettings> build() {
    _database = AppDatabase();

    return getSettings();
  }

  Future<AppSettings> getSettings() async {
    List<Map<String, dynamic>> rows = await _database.query(tableName, where: 'id = ?', whereArgs: [ 0 ]);
    if (rows.isNotEmpty) {
      return AppSettings.fromJson(rows.first);
    } else {
      return AppSettings(id: 0, libraryPath: join(getHomeFolder(), 'Pictures'), fontSize: 12);
    }
  }

  Future<int> updateSettings(AppSettings appSettings) async {
    int rowId = await _database.insert(tableName, appSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    state = await AsyncValue.guard(() => getSettings());
    return rowId;
  }
}