import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_folder_settings_repository.dart';
import '../misc/utils.dart';
import '../models/folder_ui_settings.dart';

part 'folder_settings_repository.g.dart';

@riverpod
class FolderSettingsRepository extends _$FolderSettingsRepository implements IFolderSettingsRepository {
  static const String tableName = 'folder_settings';

  late final AppDatabase _db;

  @override
  Future<FolderUISettings> build(String path) {
    ref.keepAlive();
    _db = ref.read(appDatabaseProvider.notifier);
    return getSettings(path);
  }

  @override
  Future<FolderUISettings> getSettings(String path) async {
    List<Map<String, dynamic>> rows = await _db.query(tableName, where: 'entity = ?', whereArgs: [ path ]);

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

  @override
  Future<void> updateSettings(FolderUISettings folderSettings) async {
    await _db.insert(tableName, folderSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    state = AsyncValue.data(folderSettings);
  }

  @override
  updateShowDetailedView(bool showDetailedView) {
    state.when(
        data: (FolderUISettings settings) => updateSettings(settings.copyWith(detailedView: showDetailedView)),
        error: (e, st) => null,
        loading: () => null);
  }

  @override
  void updateShowHiddenFiles(bool showHiddenFiles) {
    state.when(
        data: (FolderUISettings settings) => updateSettings(settings.copyWith(showHiddenFiles: showHiddenFiles)),
        error: (e, st) => null,
        loading: () => null);
  }
}