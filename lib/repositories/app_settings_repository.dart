import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../misc/utils.dart';
import '../models/app_settings.dart';
import '../providers/shackleton_theme.dart';

part 'app_settings_repository.g.dart';

@riverpod
class AppSettingsRepository extends _$AppSettingsRepository {
  late AppDatabase _database;

  static const String tableName = 'app_settings';
  static const String createAppSettings = '''
        create table if not exists $tableName(
          id                integer primary key, 
          libraryPath       text    not null,
          fontSize          int     not null
          );
          ''';

  @override
  Future<AppSettings> build() {
    _database = AppDatabase();

    return getSettings();
  }

  Future<AppSettings> getSettings() async {
    late AppSettings appSettings;
    List<Map<String, dynamic>> rows = await _database.query(tableName, where: 'id = ?', whereArgs: [ 0 ]);
    if (rows.isNotEmpty) {
      appSettings = AppSettings.fromJson(rows.first);
    } else {
      appSettings = AppSettings(id: 0, libraryPath: join(getHomeFolder(), 'Pictures'), fontSize: 12);
    }

    ref.read(shackletonThemeProvider.notifier).setFontSize(appSettings.fontSize.toDouble());
    return appSettings;
  }

  Future<int> updateSettings(AppSettings appSettings) async {
    ref.read(shackletonThemeProvider.notifier).setFontSize(appSettings.fontSize.toDouble());

    int rowId = await _database.insert(tableName, appSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    state = await AsyncValue.guard(() => getSettings());
    return rowId;
  }
}