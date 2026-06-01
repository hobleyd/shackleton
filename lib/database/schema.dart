import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// All DDL for the Shackleton database in one place.
///
/// Version history:
///   1 — initial schema (files, tags, file_tags, folder_settings,
///                        app_settings, favourites)
///   2 — split legacy comma-separated tags in tags table
///   3 — face recognition tables (face_identities, file_faces,
///                                 file_face_scan_status)
///   4 — gps_lat / gps_lng columns on files (GPS cache)
class AppSchema {
  AppSchema._();

  // ── files ──────────────────────────────────────────────────────────────────

  static const String createFiles = '''
      create table if not exists files(
        id      integer primary key,
        path    text    not null,
        gps_lat real,
        gps_lng real,
        unique (path) on conflict ignore);
      ''';

  static const String createFilesIndex =
      'create index if not exists files_idx on files(path);';

  // ── tags ───────────────────────────────────────────────────────────────────

  static const String createTags = '''
      create table if not exists tags(
        id  integer primary key,
        tag text    not null,
        unique (tag) on conflict ignore);
      ''';

  // ── file_tags ──────────────────────────────────────────────────────────────

  static const String createFileTags = '''
      create table if not exists file_tags(
        fileId integer not null,
        tagId  integer not null,
        foreign key(fileId) references files(id),
        foreign key(tagId)  references tags(id));
      ''';

  static const String createFileTagsFileIndex =
      'create index if not exists file_tags_file_idx on file_tags(fileId);';

  static const String createFileTagsTagIndex =
      'create index if not exists file_tags_tag_idx on file_tags(tagId);';

  // ── folder_settings ────────────────────────────────────────────────────────

  static const String createFolderSettings = '''
      create table if not exists folder_settings(
        entity          text    primary key,
        width           int     not null,
        detailedView    int     not null,
        showHiddenFiles int     not null,
        unique (entity) on conflict ignore);
      ''';

  static const String createFolderSettingsIndex =
      'create index if not exists folder_settings_idx on folder_settings(entity);';

  // ── app_settings ───────────────────────────────────────────────────────────

  static const String createAppSettings = '''
      create table if not exists app_settings(
        id          integer primary key,
        libraryPath text    not null,
        fontSize    int     not null);
      ''';

  // ── favourites ─────────────────────────────────────────────────────────────

  static const String createFavourites = '''
      create table if not exists favourites(
        id         integer primary key,
        path       text    not null,
        name       text    not null,
        sort_order int     not null,
        unique (path) on conflict ignore);
      ''';

  static const String createFavouritesIndex =
      'create index if not exists favourites_idx on favourites(path);';

  // ── face_identities ────────────────────────────────────────────────────────

  static const String createFaceIdentities = '''
      create table if not exists face_identities(
        id        integer primary key autoincrement,
        name      text    not null,
        embedding blob    not null,
        unique (name) on conflict replace);
      ''';

  // ── file_faces ─────────────────────────────────────────────────────────────

  static const String createFileFaces = '''
      create table if not exists file_faces(
        id          integer primary key autoincrement,
        file_id     integer not null references files(id) on delete cascade,
        face_index  integer not null,
        embedding   blob    not null,
        bbox_x      real    not null,
        bbox_y      real    not null,
        bbox_w      real    not null,
        bbox_h      real    not null,
        confidence  real    not null,
        identity_id integer references face_identities(id) on delete set null,
        unique (file_id, face_index) on conflict replace);
      ''';

  // ── file_face_scan_status ──────────────────────────────────────────────────

  static const String createFileFaceScanStatus = '''
      create table if not exists file_face_scan_status(
        file_id    integer primary key references files(id) on delete cascade,
        scanned_at integer not null);
      ''';

  // ── helpers ────────────────────────────────────────────────────────────────

  /// Creates all tables and indices for schema version 1.
  static Future<void> createAll(DatabaseExecutor db) async {
    await db.execute(createFiles);
    await db.execute(createTags);
    await db.execute(createFileTags);
    await db.execute(createFolderSettings);
    await db.execute(createAppSettings);
    await db.execute(createFavourites);
    await db.execute(createFilesIndex);
    await db.execute(createFolderSettingsIndex);
    await db.execute(createFavouritesIndex);
    await db.execute(createFileTagsFileIndex);
    await db.execute(createFileTagsTagIndex);
  }

  static Future<void> migrateV5AddFileTagsIndices(DatabaseExecutor db) async {
    await db.execute(createFileTagsFileIndex);
    await db.execute(createFileTagsTagIndex);
  }

  /// Creates face recognition tables for schema version 3.
  static Future<void> createFaceTables(DatabaseExecutor db) async {
    await db.execute(createFaceIdentities);
    await db.execute(createFileFaces);
    await db.execute(createFileFaceScanStatus);
  }

  /// Adds GPS coordinate columns to the files table (schema version 4).
  static Future<void> migrateV4AddGpsToFiles(DatabaseExecutor db) async {
    await db.execute('ALTER TABLE files ADD COLUMN gps_lat REAL');
    await db.execute('ALTER TABLE files ADD COLUMN gps_lng REAL');
  }
}
