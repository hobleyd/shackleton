import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../misc/utils.dart';
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

  Future<void> updateSettings(FolderUISettings folderSettings) async {
    _database.insert(tableName, folderSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    state = AsyncValue.data(folderSettings);
  }

  updateShowDetailedView(bool showDetailedView) {
    state.when(
        data: (FolderUISettings settings) => updateSettings(settings.copyWith(detailedView: showDetailedView)),
        error: (e, st) => null,
        loading: () => null);
  }

  void updateShowHiddenFiles(bool showHiddenFiles) {
    state.when(
        data: (FolderUISettings settings) => updateSettings(settings.copyWith(showHiddenFiles: showHiddenFiles)),
        error: (e, st) => null,
        loading: () => null);
  }
}