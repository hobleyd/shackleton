import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../models/folder_ui_settings.dart';

class FolderSettingsRepository {
  late AppDatabase db;
  Map<String, FolderUISettings> folderSettings = {};

  // I know Riverpod says that we should not be using Singletons, but the provider pattern keeps creating
  // new instances. If someone can tell me what I am doing wrong, I'd appreciate it.
  FolderSettingsRepository._privateConstructor();
  static final FolderSettingsRepository _instance = FolderSettingsRepository._privateConstructor();
  factory FolderSettingsRepository(AppDatabase db) {
    _instance.db = db;
    return _instance;
  }

  static const String tableName = 'folder_settings';
  static const String createFolderSettings = '''
        create table if not exists $tableName(
          entity       text    primary key,
          width        int     not null,
          isDropZone   int     not null,
          unique (entity) on conflict ignore);
        ''';
  static const String folderSettingsIndex = 'create index ${tableName}_idx on $tableName(entity);';

  Future<void> getSettings() async {
    List<Map<String, dynamic>> rows = await db.query(tableName);

    for (var row in rows) {
      FolderUISettings fuss = FolderUISettings.fromJson(row);
      folderSettings[fuss.entity.path] = fuss;
    }
  }

  Future<int> update(FolderUISettings settings) async {
    folderSettings[settings.entity.path] = settings;
    return db.insert(tableName, settings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

}