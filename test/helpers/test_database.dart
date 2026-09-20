import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// AppDatabase subclass that uses an in-memory SQLite database for tests.
/// Each instance gets its own isolated in-memory database.
class InMemoryAppDatabase extends AppDatabase {
  @override
  Future<Database> build() async {
    sqfliteFfiInit();
    return databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 4,
        // sqflite caches connections by path when singleInstance is true
        // (the default), so every test opening the same ":memory:" path
        // would otherwise share one database and leak state across tests.
        singleInstance: false,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await AppSchema.createAll(db);
          await AppSchema.createFaceTables(db);
        },
      ),
    );
  }
}

/// Returns a ProviderContainer wired with an in-memory database.
/// Call [container.dispose()] in tearDown.
ProviderContainer createTestContainer() {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
    ],
  );
}
