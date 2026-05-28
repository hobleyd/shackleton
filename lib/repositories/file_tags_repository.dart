import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/notify.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_file_tags_repository.dart';
import '../models/entity.dart';
import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';

part 'file_tags_repository.g.dart';

@riverpod
class FileTagsRepository extends _$FileTagsRepository implements IFileTagsRepository {
  late final AppDatabase _db;

  @override
  Future<List<Tag>> build() {
    ref.keepAlive();
    _db = ref.read(appDatabaseProvider.notifier);
    return getTags();
  }

  @override
  Future<bool> cleanOrphanedTags() async {
    final notify = ref.read(notifyProvider.notifier);
    List<Map<String, dynamic>> results = await _db.query('files', columns: ['path']);
    if (results.isNotEmpty) {
      for (var file in results) {
        String path = file['path'];
        if (!File(path).existsSync()) {
          notify.addNotification(message: "$path doesn't exist, removing tags.");
          removeTagsForEntity(Entity(path: path));
        }
      }

      return true;
    }

    return false;
  }

  Future<bool> deleteOrphanedTags(int tagId) async {
    int tagCount = await _db.getCount('file_tags', where: 'tagId = ?', whereArgs: [tagId.toString()]);

    if (tagCount == 0) {
      await _db.delete('tags', where: 'id = ?', whereArgs: [tagId.toString()]);
      return true;
    }

    return false;
  }

  Future<int> getEntityId(Entity entity) async {
    if (entity.id == null) {
      List<Map<String, dynamic>> results = await _db.query('files', columns: ['id'], where: 'path = ?', whereArgs: [entity.path]);
      if (results.isNotEmpty) {
        entity.id = results.first['id'];
      } else {
        entity.id = await _db.insert('files', entity.toMap());
      }
    }

    return entity.id!;
  }

  Future<int> getTagId(Tag tag) async {
    if (tag.id == null) {
      List<Map> tagRecords = await _db.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
      if (tagRecords.isNotEmpty) {
        return tagRecords.first['id'] as int;
      }
      else {
        return await _db.insert('tags', tag.toMap());
      }
    }

    return tag.id!;
  }

  @override
  Future<List<FileOfInterest>> getFilesForTag(Tag tag) async {
    final rows = await _db.rawQuery(
      'select * from files where id in '
      '(select fileId from file_tags, tags '
      'where tags.id = file_tags.tagId and tags.tag = ?)',
      [tag.tag],
    );
    return [
      for (final row in rows)
        if (File(row['path'] as String).existsSync())
          FileOfInterest(entity: File(row['path'] as String)),
    ];
  }

  @override
  Future<List<Tag>> getTags() async {
    List<Map<String, dynamic>> results = await _db.query('tags', columns: ['id', 'tag'], orderBy: 'tag');
    return results.map((row) => Tag.fromMap(row)).toList();
  }

  Future<Set<int>> getTagIdsForEntity(Entity entity) async {
    List<Map<String, dynamic>> results = await _db.query('file_tags', columns: ['tagId'], where: 'fileId = ?', whereArgs: [entity.id.toString()]);
    return results.map((row) => row.values.first).whereType<int>().toSet();
  }

  Future<bool> removeTagForEntity(Entity entity, int tagId) async {
    int id = await getEntityId(entity);
    await _db.delete('file_tags', where: 'fileId = ? and tagId = ?', whereArgs: [id.toString(), tagId.toString()]);
    return await deleteOrphanedTags(tagId);
  }

  @override
  Future<void> removeTagsForEntity(Entity entity, { bool deleteEntity = true }) async {
    int id = await getEntityId(entity);
    Set<int> tags = await getTagIdsForEntity(entity);
    await _db.delete('file_tags', where: 'fileId = ?', whereArgs: [id.toString()]);

    bool refreshState = false;
    for (int tagId in tags) {
      bool deleted = await deleteOrphanedTags(tagId);
      if (deleted) {
        refreshState = true;
      }
    }

    if (deleteEntity) {
      await _db.delete('files', where: 'path = ?', whereArgs: [entity.path]);
    }

    if (refreshState) {
      final tags = await getTags();
      if (ref.mounted) state = AsyncData(tags);
    }
  }

  @override
  Future<void> addTagToFile(String filePath, String tagName) async {
    if (tagName.trim().isEmpty) return;

    await _db.transaction((txn) async {
      final fileRows = await txn.query('files',
          columns: ['id'], where: 'path = ?', whereArgs: [filePath]);
      final fileId = fileRows.isNotEmpty
          ? fileRows.first['id'] as int
          : await txn.insert('files', {'path': filePath});

      final tagRows = await txn.query('tags',
          columns: ['id'], where: 'tag = ?', whereArgs: [tagName]);
      final tagId = tagRows.isNotEmpty
          ? tagRows.first['id'] as int
          : await txn.insert('tags', {'tag': tagName});

      final existing = await txn.query('file_tags',
          where: 'fileId = ? and tagId = ?', whereArgs: [fileId, tagId]);
      if (existing.isEmpty) {
        await txn.insert('file_tags', {'fileId': fileId, 'tagId': tagId});
      }
    });

    final tags = await getTags();
    if (ref.mounted) state = AsyncData(tags);
  }

  @override
  Future<FileMetaData?> getMetadataForFile(
      String path, FileOfInterest entity) async {
    final fileRows = await _db.query('files',
        columns: ['id', 'gps_lat', 'gps_lng'],
        where: 'path = ?',
        whereArgs: [path]);
    if (fileRows.isEmpty) return null;

    final fileId = fileRows.first['id'] as int;
    final lat = fileRows.first['gps_lat'] as double?;
    final lng = fileRows.first['gps_lng'] as double?;

    final tagRows = await _db.rawQuery(
      'SELECT t.id, t.tag FROM tags t '
      'JOIN file_tags ft ON ft.tagId = t.id '
      'WHERE ft.fileId = ?',
      [fileId],
    );
    final tags = tagRows
        .map((r) => Tag(id: r['id'] as int?, tag: r['tag'] as String))
        .toList();
    final gps = (lat != null && lng != null) ? LatLng(lat, lng) : null;

    return FileMetaData(entity: entity, tags: tags, gpsLocation: gps);
  }

  @override
  Future<void> writeTags(Entity entity) async {
    // Always ensure the file row exists in the DB. This guarantees that
    // getMetadataForFile will find it on the next visit, even for untagged
    // files that would otherwise never enter the full transaction below.
    double? existingGpsLat;
    double? existingGpsLng;

    if (entity.id == null) {
      final rows = await _db.query('files',
          columns: ['id', 'gps_lat', 'gps_lng'],
          where: 'path = ?',
          whereArgs: [entity.path]);
      if (rows.isNotEmpty) {
        entity.id = rows.first['id'] as int;
        existingGpsLat = rows.first['gps_lat'] as double?;
        existingGpsLng = rows.first['gps_lng'] as double?;
      } else {
        entity.id = await _db.insert('files', {'path': entity.path},
            conflictAlgorithm: ConflictAlgorithm.ignore);
        if (entity.id == 0) {
          // Concurrent insert won the race — re-fetch.
          final r = await _db.query('files',
              columns: ['id', 'gps_lat', 'gps_lng'],
              where: 'path = ?',
              whereArgs: [entity.path]);
          entity.id = r.first['id'] as int;
          existingGpsLat = r.first['gps_lat'] as double?;
          existingGpsLng = r.first['gps_lng'] as double?;
        }
      }
    }

    // Fast path: skip the transaction when tags + GPS are already up to date.
    final incomingNames = (entity.tags as List<Tag>?)
            ?.where((t) => t.tag.isNotEmpty)
            .map((t) => t.tag)
            .toSet() ??
        <String>{};
    final existingTagRows = await _db.rawQuery(
      'SELECT t.tag FROM tags t '
      'JOIN file_tags ft ON ft.tagId = t.id '
      'WHERE ft.fileId = ?',
      [entity.id],
    );
    final existingNames =
        existingTagRows.map((r) => r['tag'] as String).toSet();

    final incomingGps = entity.metadata?.gpsLocation;
    final gpsUnchanged = incomingGps == null
        ? existingGpsLat == null
        : existingGpsLat != null &&
            (incomingGps.latitude - existingGpsLat).abs() < 1e-6 &&
            (incomingGps.longitude - existingGpsLng!).abs() < 1e-6;

    if (incomingNames.length == existingNames.length &&
        incomingNames.containsAll(existingNames) &&
        gpsUnchanged) {
      return;
    }

    bool changed = false;

    await _db.transaction((txn) async {
      // Update GPS coordinates if they changed.
      if (!gpsUnchanged) {
        await txn.update(
          'files',
          {
            'gps_lat': incomingGps?.latitude,
            'gps_lng': incomingGps?.longitude,
          },
          where: 'id = ?',
          whereArgs: [entity.id],
        );
        changed = true;
      }

      // Resolve/create tag records for incoming tags.
      final incomingTagIds = <int>{};
      for (final tag in (entity.tags as List<Tag>? ?? <Tag>[])) {
        if (tag.tag.isEmpty) continue;
        if (tag.id == null) {
          final existing = await txn.query('tags',
              columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
          tag.id = existing.isNotEmpty
              ? existing.first['id'] as int
              : await txn.insert('tags', tag.toMap());
          if (tag.id == 0) {
            final refetch = await txn.query('tags',
                columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
            tag.id = refetch.first['id'] as int;
          }
        }
        incomingTagIds.add(tag.id!);
        changed = true;
      }

      // Get currently stored tag IDs for this entity.
      final storedRows = await txn.query('file_tags',
          columns: ['tagId'], where: 'fileId = ?', whereArgs: [entity.id]);
      final storedTagIds = storedRows.map((r) => r['tagId'] as int).toSet();

      // Remove junction rows for tags no longer on the entity.
      for (final tagId in storedTagIds) {
        if (!incomingTagIds.contains(tagId)) {
          await txn.delete('file_tags',
              where: 'fileId = ? and tagId = ?',
              whereArgs: [entity.id, tagId]);
          final refs = await txn.rawQuery(
              'select count(*) as cnt from file_tags where tagId = ?', [tagId]);
          if ((refs.first['cnt'] as int) == 0) {
            await txn.delete('tags', where: 'id = ?', whereArgs: [tagId]);
          }
          changed = true;
        }
      }

      // Insert new junction records.
      for (final tag in (entity.tags as List<Tag>? ?? <Tag>[])) {
        if (tag.tag.isEmpty || tag.id == null) continue;
        final existing = await txn.query('file_tags',
            columns: ['tagId'],
            where: 'tagId = ? and fileId = ?',
            whereArgs: [tag.id, entity.id]);
        if (existing.isEmpty) {
          await txn.insert('file_tags', {'tagId': tag.id, 'fileId': entity.id});
        }
      }
    });

    if (changed) {
      final tags = await getTags();
      if (ref.mounted) state = AsyncData(tags);
    }
  }
}