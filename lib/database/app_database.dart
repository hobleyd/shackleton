import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../repositories/app_settings_repository.dart';
import '../repositories/favourites_repository.dart';
import '../repositories/file_tags_repository.dart';
import '../repositories/folder_settings_repository.dart';

part 'app_database.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDb(AppDbRef ref) {
  return AppDatabase();
}

class AppDatabase {
  late Database _cachedStorage;

  // I know Riverpod says that we should not be using Singletons, but the provider pattern keeps creating
  // new instances. If someone can tell me what I am doing wrong, I'd appreciate it.
  AppDatabase._privateConstructor();
  static final AppDatabase _instance = AppDatabase._privateConstructor();
  factory AppDatabase() {
    return _instance;
  }

  void _createTables(Database db, int oldVersion, int newVersion) {
    _enableForeignKeys(db);
    if (oldVersion < 1) {
      db.execute(FileTagsRepository.createFiles);
      db.execute(FileTagsRepository.createTags);
      db.execute(FileTagsRepository.createFileTags);
      db.execute(FolderSettingsRepository.createFolderSettings);
      db.execute(AppSettingsRepository.createAppSettings);
      db.execute(FavouritesRepository.createFavourites);

      db.execute(FileTagsRepository.createFilesIndex);
      db.execute(FolderSettingsRepository.folderSettingsIndex);
      db.execute(FavouritesRepository.createFavouritesIndex);
    }
    return;
  }

  Future _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<String> _getDatabasePath() async {
    String database = "";
    if (Platform.isWindows) {
      database = path.join(Platform.environment['APPDATA']!, 'Shackleton');
    } else {
      database = path.join(Platform.environment['HOME']!, '.shackleton');
    }
    await Directory(database).create(recursive: true);

    database = path.join(database, 'shackleton.db');
    return database;
  }

  Future<void> openDatabase() async {
    sqfliteFfiInit();

    _cachedStorage = await databaseFactoryFfi.openDatabase(await _getDatabasePath(),
        options: OpenDatabaseOptions(
            version: 1,
            onConfigure: (db) {
              _enableForeignKeys(db);
            },
            onCreate: (db, version) {
              _createTables(db, 0, version);
            },
            onOpen: (db) {

            },
            onUpgrade: (db, oldVersion, newVersion) {
              _createTables(db, oldVersion, newVersion);
            }));
  }

  void close() {
    _cachedStorage.close();
  }

  Future<int> delete(String table, { String? where, List<String>? whereArgs }) {
    return _cachedStorage.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> getCount(String table, { String? where, List<dynamic>? whereArgs }) async {
    List<Map<String, dynamic>> results = await _cachedStorage.query(table, columns: ['count(*) as count'], where: where, whereArgs: whereArgs);
    return results.first['count'] as int;
  }

  Future<int> insert(String table, Map<String, dynamic> rows, { ConflictAlgorithm? conflictAlgorithm }) async {
    return _cachedStorage.insert(table, rows, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query(String table, { List<String>? columns, String? where, List<dynamic>? whereArgs, String? orderBy }) async {
    return _cachedStorage.query(table, columns: columns, where: where, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, List<Object?>? arguments) async {
    return _cachedStorage.rawQuery(sql, arguments);
  }

  Future<int> update(String table, Map<String, dynamic> values, String? where, List<String>? whereArgs) {
    return _cachedStorage.update(table, values, where: where, whereArgs: whereArgs);
  }
}