import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AppDatabase {
  late Database _cachedStorage;

  static const String _files = '''
        create table if not exists files(
          id integer primary key,
          path text not null,
          unique (path) on conflict ignore);
          ''';
  static const String _tags = '''
        create table if not exists tags(
          id integer primary key,
          tag text not null,
          unique (name) on conflict ignore);
          ''';
  static const String _filetags = '''
        create table if not exists file_tags(
          fileId integer not null, 
          tagId integer not null, 
          foreign key(fileId) references files(id),
          foreign key(tagId) references tags(id));
          ''';
  static const String _folder_settings = '''
        create table if not exists folder_settings(
          id integer primary key,
          path text not null,
          width int not null,
          unique (path) on conflict ignore);
          ''';
  static const String _app_settings = '''
        create table if not exists app_settings(
          id integer primary key,
          libraryPath text not null,
          showHiddenFiles int not null,
          unique (path) on conflict ignore);
          ''';
  static const String _indexFiles = 'create index files_idx on files(path);';
  static const String _indexSettings = 'create index settings_idx on settings(path);';

  AppDatabase() {
    _openDatabase();
  }

  void _createTables(Database db, int oldVersion, int newVersion) {
    _enableForeignKeys(db);
    if (oldVersion < 1) {
      db.execute(_files);
      db.execute(_tags);
      db.execute(_filetags);
      db.execute(_folder_settings);
      db.execute(_app_settings);

      db.execute(_indexFiles);
      db.execute(_indexSettings);
    }
    return;
  }

  Future _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<String> _getDatabasePath() async {
    String database = "";
    if (Platform.isWindows) {
      database = Platform.environment['APPDATA']!;
    } else {
      database = path.join(Platform.environment['HOME']!, '.shackleton');
    }
    await Directory(database).create(recursive: true);

    database = path.join(database, 'shackleton.db');
    return database;
  }

  void _openDatabase() async {
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

  Future<int> insert(String table, Map<String, dynamic> rows, { ConflictAlgorithm? conflictAlgorithm }) async {
    return _cachedStorage.insert(table, rows, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query(String table, { List<String>? columns, String? where, List<dynamic>? whereArgs }) async {
    return _cachedStorage.query(table, columns: columns, where: where, whereArgs: whereArgs);
  }

}