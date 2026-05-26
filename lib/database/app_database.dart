import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'schema.dart';

part 'app_database.g.dart';

@Riverpod(keepAlive: true)
class AppDatabase extends _$AppDatabase {
  @override
  Future<Database> build() async {
    return openDatabase();
  }

  Future<Database> openDatabase() async {
    sqfliteFfiInit();

    return databaseFactoryFfi.openDatabase(
      await _getDatabasePath(),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => _enableForeignKeys(db),
        onCreate: (db, version) => _createTables(db, 0, version),
        onUpgrade: (db, oldVersion, newVersion) =>
            _createTables(db, oldVersion, newVersion),
      ),
    );
  }

  Future<void> _createTables(Database db, int oldVersion, int newVersion) async {
    await _enableForeignKeys(db);
    if (oldVersion < 1) {
      await AppSchema.createAll(db);
    }
  }

  Future<void> _enableForeignKeys(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<String> _getDatabasePath() async {
    String dbDir;
    if (Platform.isWindows) {
      dbDir = path.join(Platform.environment['APPDATA']!, 'Shackleton');
    } else {
      dbDir = path.join(Platform.environment['HOME']!, '.shackleton');
    }
    await Directory(dbDir).create(recursive: true);
    return path.join(dbDir, 'shackleton.db');
  }

  // ── transaction support ────────────────────────────────────────────────────

  Future<T> transaction<T>(Future<T> Function(Transaction txn) action) async {
    return (await future).transaction(action);
  }

  // ── query helpers ──────────────────────────────────────────────────────────

  Future<void> close() async {
    (await future).close();
  }

  Future<int> delete(String table,
      {String? where, List<String>? whereArgs}) async {
    return (await future).delete(table, where: where, whereArgs: whereArgs);
  }

  Future<int> getCount(String table,
      {String? where, List<dynamic>? whereArgs}) async {
    final results = await (await future).query(table,
        columns: ['count(*) as count'], where: where, whereArgs: whereArgs);
    return results.first['count'] as int;
  }

  Future<int> insert(String table, Map<String, dynamic> rows,
      {ConflictAlgorithm? conflictAlgorithm}) async {
    return (await future)
        .insert(table, rows, conflictAlgorithm: conflictAlgorithm);
  }

  Future<List<Map<String, dynamic>>> query(String table,
      {List<String>? columns,
      String? where,
      List<dynamic>? whereArgs,
      String? orderBy}) async {
    return (await future).query(table,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        orderBy: orderBy);
  }

  Future<List<Map<String, dynamic>>> rawQuery(
      String sql, List<Object?>? arguments) async {
    return (await future).rawQuery(sql, arguments);
  }

  Future<int> updateTable(String table, Map<String, dynamic> values,
      String? where, List<String>? whereArgs) async {
    return (await future)
        .update(table, values, where: where, whereArgs: whereArgs);
  }
}
