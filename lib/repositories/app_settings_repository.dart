import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../misc/utils.dart';
import '../models/app_settings.dart';

class AppSettingsRepository {
  late AppDatabase db;
  late AppSettings appSettings;

  // I know Riverpod says that we should not be using Singletons, but the provider pattern keeps creating
  // new instances. If someone can tell me what I am doing wrong, I'd appreciate it.
  AppSettingsRepository._privateConstructor();
  static final AppSettingsRepository _instance = AppSettingsRepository._privateConstructor();
  factory AppSettingsRepository(AppDatabase db) {
    _instance.db = db;
    return _instance;
  }

  static const String tableName = 'app_settings';
  static const String createAppSettings = '''
        create table if not exists $tableName(
          id                integer primary key, 
          detailedView      int     not null,
          libraryPath       text    not null,
          fontSize          int     not null,
          showHiddenFiles   int     not null,
          );
          ''';

  Future<void> getSettings() async {
    List<Map<String, dynamic>> rows = await db.query(tableName, where: 'id = ?', whereArgs: [ 0 ]);
    if (rows.isNotEmpty) {
      appSettings = AppSettings.fromJson(rows.first);
    } else {
      appSettings = AppSettings(id: 0, libraryPath: getHomeFolder(), fontSize: 12);
    }
  }

  Future<int> update() async {
    return db.insert(tableName, appSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }
}