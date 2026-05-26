import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/notify.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_file_tags_repository.dart';
import '../models/entity.dart';
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
      debugPrint('deleting tag: $tagId with $tagCount');
      _db.delete('tags', where: 'id = ?', whereArgs: [tagId.toString()]);
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
  Future<void> writeTags(Entity entity) async {
    bool changed = false;

    await _db.transaction((txn) async {
      // 1. Ensure file record exists.
      if (entity.id == null) {
        final rows = await txn.query('files',
            columns: ['id'], where: 'path = ?', whereArgs: [entity.path]);
        entity.id = rows.isNotEmpty
            ? rows.first['id'] as int
            : await txn.insert('files', entity.toMap());
      }

      // 2. Resolve/create tag records for incoming tags.
      final incomingTagIds = <int>{};
      for (final tag in entity.tags) {
        if (tag.tag.isEmpty) continue;
        if (tag.id == null) {
          final existing = await txn
              .query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
          tag.id = existing.isNotEmpty
              ? existing.first['id'] as int
              : await txn.insert('tags', tag.toMap());
          // Race-condition guard.
          if (tag.id == 0) {
            final refetch = await txn
                .query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
            tag.id = refetch.first['id'] as int;
          }
        }
        incomingTagIds.add(tag.id!);
        changed = true;
      }

      // 3. Get currently stored tag IDs for this entity.
      final storedRows = await txn.query('file_tags',
          columns: ['tagId'], where: 'fileId = ?', whereArgs: [entity.id]);
      final storedTagIds = storedRows.map((r) => r['tagId'] as int).toSet();

      // 4. Remove junction records for tags no longer on the entity;
      //    delete the tag row itself if no other file references it.
      for (final tagId in storedTagIds) {
        if (!incomingTagIds.contains(tagId)) {
          await txn.delete('file_tags',
              where: 'fileId = ? and tagId = ?',
              whereArgs: [entity.id, tagId]);
          final refs = await txn.rawQuery(
              'select count(*) as cnt from file_tags where tagId = ?', [tagId]);
          if ((refs.first['cnt'] as int) == 0) {
            debugPrint('deleting tag: $tagId with 0');
            await txn.delete('tags', where: 'id = ?', whereArgs: [tagId]);
          }
          changed = true;
        }
      }

      // 5. Insert new junction records.
      for (final tag in entity.tags) {
        if (tag.tag.isEmpty || tag.id == null) continue;
        final existing = await txn.query('file_tags',
            columns: ['tagId'],
            where: 'tagId = ? and fileId = ?',
            whereArgs: [tag.id, entity.id]);
        if (existing.isEmpty) {
          debugPrint(
              'attempting to insert ${entity.path} (${entity.id}) -> ${tag.tag} (${tag.id})');
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