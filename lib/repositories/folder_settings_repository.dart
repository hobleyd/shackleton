import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/misc/utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/folder_ui_settings.dart';

part 'folder_settings_repository.g.dart';

@riverpod
class FolderSettingsRepository extends _$FolderSettingsRepository {
  late AppDatabase _database;

  static const String tableName = 'folder_settings';
  static const String createFolderSettings = '''
        create table if not exists $tableName(
          entity          text    primary key,
          width           int     not null,
          detailedView    int     not null,
          showHiddenFiles int     not null,
          unique (entity) on conflict ignore);
        ''';
  static const String folderSettingsIndex = 'create index ${tableName}_idx on $tableName(entity);';

  @override
  Future<FolderUISettings> build(String path) {
    _database = AppDatabase();

    return getSettings(path);
  }

  Future<FolderUISettings> getSettings(String path) async {
    List<Map<String, dynamic>> rows = await _database.query(tableName, where: 'entity = ?', whereArgs: [ path ]);

    if (rows.isNotEmpty) {
      return FolderUISettings.fromJson(rows.first);
    } else {
      return FolderUISettings(
          entity: getEntity(path),
          width: 200,
          detailedView: false,
          showHiddenFiles: false);
    }
  }

  Future<int> updateSettings(FolderUISettings folderSettings) async {
    int rowId = await _database.insert(tableName, folderSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    state = await AsyncValue.guard(() => getSettings(folderSettings.entity.path));
    return rowId;
  }
}