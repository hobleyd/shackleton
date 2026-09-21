import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/database/schema.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON;'),
        onCreate: (d, _) => AppSchema.createAll(d),
      ),
    );
  });

  tearDown(() => db.close());

  group('AppSchema.createAll', () {
    test('creates all expected tables', () async {
      final tables = await db.rawQuery(
        "select name from sqlite_master where type='table' order by name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, containsAll({'files', 'tags', 'file_tags', 'folder_settings', 'app_settings', 'favourites'}));
    });

    test('creates expected indices', () async {
      final indices = await db.rawQuery(
        "select name from sqlite_master where type='index' and name not like 'sqlite_%' order by name",
      );
      final names = indices.map((r) => r['name'] as String).toSet();
      expect(names, containsAll({'files_idx', 'folder_settings_idx', 'favourites_idx'}));
    });

    test('is idempotent — createAll can be called twice without error', () async {
      await expectLater(AppSchema.createAll(db), completes);
    });

    test('files table enforces unique path constraint', () async {
      await db.insert('files', {'path': '/a/b.jpg'});
      await db.insert('files', {'path': '/a/b.jpg'}); // conflict ignore
      final row = await db.rawQuery('select count(*) as cnt from files where path = ?', ['/a/b.jpg']);
      final count = row.first['cnt'] as int;
      expect(count, 1);
    });

    test('tags table enforces unique tag constraint', () async {
      await db.insert('tags', {'tag': 'nature'});
      await db.insert('tags', {'tag': 'nature'}); // conflict ignore
      final row = await db.rawQuery('select count(*) as cnt from tags where tag = ?', ['nature']);
      final count = row.first['cnt'] as int;
      expect(count, 1);
    });

    test('file_tags enforces foreign key to files', () async {
      await db.insert('tags', {'tag': 'solo'});
      expect(
        () => db.insert('file_tags', {'fileId': 9999, 'tagId': 1}),
        throwsA(anything),
      );
    });

    test('file_tags enforces foreign key to tags', () async {
      await db.insert('files', {'path': '/x.jpg'});
      expect(
        () => db.insert('file_tags', {'fileId': 1, 'tagId': 9999}),
        throwsA(anything),
      );
    });
  });

  group('AppDatabase.migrateV2SplitCommaTagsInDb', () {
    late Directory tempDir;
    late Database migDb;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('migration_v2_test_');
      migDb = await databaseFactoryFfi.openDatabase(
        '${tempDir.path}/test.db',
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (d) => d.execute('PRAGMA foreign_keys = ON;'),
          onCreate: (d, _) => AppSchema.createAll(d),
        ),
      );
    });

    tearDown(() async {
      if (migDb.isOpen) await migDb.close();
      await tempDir.delete(recursive: true);
    });

    test('splits a single comma-separated IPTC tag into individual rows', () async {
      final fileId = await migDb.insert('files', {'path': '/photo.jpg'});
      final tagId = await migDb.insert('tags', {'tag': 'Annette, Bob, David, Diane'});
      await migDb.insert('file_tags', {'tagId': tagId, 'fileId': fileId});

      await AppDatabase.migrateV2SplitCommaTagsInDb(migDb);

      final tags = await migDb.query('tags', columns: ['tag'], orderBy: 'tag');
      expect(tags.map((r) => r['tag']), containsAll(['Annette', 'Bob', 'David', 'Diane']));
      expect(tags.length, equals(4));

      final junctions = await migDb.query('file_tags', where: 'fileId = ?', whereArgs: [fileId]);
      expect(junctions.length, equals(4));
    });

    test('leaves single-word tags unchanged', () async {
      final fileId = await migDb.insert('files', {'path': '/photo.jpg'});
      final tagId = await migDb.insert('tags', {'tag': 'nature'});
      await migDb.insert('file_tags', {'tagId': tagId, 'fileId': fileId});

      await AppDatabase.migrateV2SplitCommaTagsInDb(migDb);

      final tags = await migDb.query('tags', columns: ['tag']);
      expect(tags.map((r) => r['tag']).toList(), equals(['nature']));
    });

    test('merges with existing individual tags and avoids duplicate junctions', () async {
      final fileId = await migDb.insert('files', {'path': '/photo.jpg'});
      // Pre-existing individual tag
      final existingId = await migDb.insert('tags', {'tag': 'Bob'});
      await migDb.insert('file_tags', {'tagId': existingId, 'fileId': fileId});
      // Legacy comma tag that overlaps with existing
      final commaId = await migDb.insert('tags', {'tag': 'Annette, Bob'});
      await migDb.insert('file_tags', {'tagId': commaId, 'fileId': fileId});

      await AppDatabase.migrateV2SplitCommaTagsInDb(migDb);

      final tags = await migDb.query('tags', columns: ['tag'], orderBy: 'tag');
      expect(tags.map((r) => r['tag']), containsAll(['Annette', 'Bob']));
      expect(tags.length, equals(2));

      // Exactly one file_tags row per unique tag for this file
      final junctions = await migDb.query('file_tags', where: 'fileId = ?', whereArgs: [fileId]);
      expect(junctions.length, equals(2));
    });
  });

  group('AppSchema.createFaceTables', () {
    setUp(() => AppSchema.createFaceTables(db));

    test('creates all expected face tables', () async {
      final tables = await db.rawQuery(
        "select name from sqlite_master where type='table' order by name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, containsAll({'face_identities', 'file_faces', 'file_face_scan_status'}));
    });

    test('face_identities replaces on duplicate name', () async {
      await db.insert('face_identities', {'name': 'Alice', 'embedding': Uint8List(4)});
      await db.insert('face_identities', {'name': 'Alice', 'embedding': Uint8List(8)});

      final rows = await db.query('face_identities', where: 'name = ?', whereArgs: ['Alice']);
      expect(rows, hasLength(1));
      expect((rows.first['embedding'] as Uint8List).length, 8);
    });

    test('file_faces are deleted when the parent file is deleted (cascade)', () async {
      final fileId = await db.insert('files', {'path': '/a.jpg'});
      await db.insert('file_faces', {
        'file_id': fileId,
        'face_index': 0,
        'embedding': Uint8List(4),
        'bbox_x': 0.0,
        'bbox_y': 0.0,
        'bbox_w': 1.0,
        'bbox_h': 1.0,
        'confidence': 0.9,
      });

      await db.delete('files', where: 'id = ?', whereArgs: [fileId]);

      final rows = await db.query('file_faces', where: 'file_id = ?', whereArgs: [fileId]);
      expect(rows, isEmpty);
    });

    test('file_faces.identity_id is cleared, not the row deleted, when the identity is deleted', () async {
      final fileId = await db.insert('files', {'path': '/a.jpg'});
      final identityId = await db.insert('face_identities', {'name': 'Alice', 'embedding': Uint8List(4)});
      await db.insert('file_faces', {
        'file_id': fileId,
        'face_index': 0,
        'embedding': Uint8List(4),
        'bbox_x': 0.0,
        'bbox_y': 0.0,
        'bbox_w': 1.0,
        'bbox_h': 1.0,
        'confidence': 0.9,
        'identity_id': identityId,
      });

      await db.delete('face_identities', where: 'id = ?', whereArgs: [identityId]);

      final rows = await db.query('file_faces', where: 'file_id = ?', whereArgs: [fileId]);
      expect(rows, hasLength(1));
      expect(rows.first['identity_id'], isNull);
    });

    test('file_faces replaces on duplicate (file_id, face_index)', () async {
      final fileId = await db.insert('files', {'path': '/a.jpg'});
      final row = {
        'file_id': fileId,
        'face_index': 0,
        'bbox_x': 0.0,
        'bbox_y': 0.0,
        'bbox_w': 1.0,
        'bbox_h': 1.0,
        'confidence': 0.9,
      };
      await db.insert('file_faces', {...row, 'embedding': Uint8List(4)});
      await db.insert('file_faces', {...row, 'embedding': Uint8List(8)});

      final rows = await db.query('file_faces', where: 'file_id = ? AND face_index = ?', whereArgs: [fileId, 0]);
      expect(rows, hasLength(1));
      expect((rows.first['embedding'] as Uint8List).length, 8);
    });

    test('file_face_scan_status is deleted when the parent file is deleted (cascade)', () async {
      final fileId = await db.insert('files', {'path': '/a.jpg'});
      await db.insert('file_face_scan_status', {'file_id': fileId, 'scanned_at': 1000});

      await db.delete('files', where: 'id = ?', whereArgs: [fileId]);

      final rows = await db.query('file_face_scan_status', where: 'file_id = ?', whereArgs: [fileId]);
      expect(rows, isEmpty);
    });
  });

  group('AppSchema.migrateV4AddGpsToFiles', () {
    late Database legacyDb;

    setUp(() async {
      // Simulate a pre-v4 files table: no gps_lat/gps_lng columns.
      legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (d, _) => d.execute('''
              create table files(
                id   integer primary key,
                path text    not null,
                unique (path) on conflict ignore);
              '''),
        ),
      );
    });

    tearDown(() => legacyDb.close());

    test('adds gps_lat and gps_lng columns without losing existing rows', () async {
      final fileId = await legacyDb.insert('files', {'path': '/a.jpg'});

      await AppSchema.migrateV4AddGpsToFiles(legacyDb);

      final rows = await legacyDb.query('files', where: 'id = ?', whereArgs: [fileId]);
      expect(rows, hasLength(1));
      expect(rows.first['path'], '/a.jpg');
      expect(rows.first.containsKey('gps_lat'), isTrue);
      expect(rows.first['gps_lat'], isNull);
    });

    test('gps columns accept values after migration', () async {
      await AppSchema.migrateV4AddGpsToFiles(legacyDb);

      await legacyDb.insert('files', {'path': '/gps.jpg', 'gps_lat': 27.47, 'gps_lng': 153.02});

      final rows = await legacyDb.query('files', where: 'path = ?', whereArgs: ['/gps.jpg']);
      expect(rows.first['gps_lat'], 27.47);
      expect(rows.first['gps_lng'], 153.02);
    });
  });

  group('AppSchema.migrateV5AddFileTagsIndices', () {
    late Database legacyDb;

    setUp(() async {
      // Simulate a pre-v5 file_tags table: created without its indices.
      legacyDb = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          singleInstance: false,
          onCreate: (d, _) => d.execute(AppSchema.createFileTags),
        ),
      );
    });

    tearDown(() => legacyDb.close());

    test('adds the file_tags indices', () async {
      final before = await legacyDb.rawQuery(
        "select name from sqlite_master where type='index' and name not like 'sqlite_%'",
      );
      expect(before, isEmpty);

      await AppSchema.migrateV5AddFileTagsIndices(legacyDb);

      final after = await legacyDb.rawQuery(
        "select name from sqlite_master where type='index' and name not like 'sqlite_%'",
      );
      final names = after.map((r) => r['name'] as String).toSet();
      expect(names, containsAll({'file_tags_file_idx', 'file_tags_tag_idx'}));
    });

    test('is idempotent — can be called twice without error', () async {
      await AppSchema.migrateV5AddFileTagsIndices(legacyDb);
      await expectLater(AppSchema.migrateV5AddFileTagsIndices(legacyDb), completes);
    });
  });

  group('Transaction atomicity', () {
    test('all inserts succeed within a transaction', () async {
      await db.transaction((txn) async {
        final fileId = await txn.insert('files', {'path': '/txn/photo.jpg'});
        final tagId = await txn.insert('tags', {'tag': 'scenic'});
        await txn.insert('file_tags', {'fileId': fileId, 'tagId': tagId});
      });

      final files = await db.query('files', where: 'path = ?', whereArgs: ['/txn/photo.jpg']);
      final tags = await db.query('tags', where: 'tag = ?', whereArgs: ['scenic']);
      final junctions = await db.rawQuery('select * from file_tags where fileId = ? and tagId = ?', [files.first['id'], tags.first['id']]);

      expect(files, hasLength(1));
      expect(tags, hasLength(1));
      expect(junctions, hasLength(1));
    });

    test('transaction rolls back on exception — no partial state', () async {
      try {
        await db.transaction((txn) async {
          await txn.insert('files', {'path': '/rollback/photo.jpg'});
          throw Exception('simulated failure');
        });
      } catch (_) {}

      final files = await db.query('files', where: 'path = ?', whereArgs: ['/rollback/photo.jpg']);
      expect(files, isEmpty);
    });

    test('AppSchema.createAll works inside a transaction', () async {
      final txnDb = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
      await txnDb.transaction((txn) async {
        await AppSchema.createAll(txn);
      });
      final tables = await txnDb.rawQuery(
        "select name from sqlite_master where type='table' order by name",
      );
      final names = tables.map((r) => r['name'] as String).toSet();
      expect(names, containsAll({'files', 'tags', 'file_tags'}));
      await txnDb.close();
    });
  });
}
