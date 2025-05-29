import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/notify.dart';

import '../database/app_database.dart';
import '../models/entity.dart';
import '../models/tag.dart';

part 'file_tags_repository.g.dart';

@riverpod
class FileTagsRepository extends _$FileTagsRepository {
  late AppDatabase _database;

  static const String createFiles = '''
        create table if not exists files(
          id integer primary key,
          path text not null,
          unique (path) on conflict ignore);
          ''';
  static const String createTags = '''
        create table if not exists tags(
          id integer primary key,
          tag text not null,
          unique (tag) on conflict ignore);
          ''';
  static const String createFileTags = '''
        create table if not exists file_tags(
          fileId integer not null, 
          tagId integer not null, 
          foreign key(fileId) references files(id),
          foreign key(tagId) references tags(id));
          ''';

  static const String createFilesIndex = 'create index files_idx on files(path);';

  @override
  Future<List<Tag>> build() {
    _database = ref.watch(appDbProvider);

    return getTags();
  }

  Future<bool> cleanOrphanedTags() async {
    List<Map<String, dynamic>> results = await _database.query('files', columns: ['path']);
    if (results.isNotEmpty) {
      for (var file in results) {
        String path = file['path'];
        if (!File(path).existsSync()) {
          ref.read(notifyProvider.notifier).addNotification(message: "$path doesn't exist, removing tags.");
          removeTagsForEntity(Entity(path: path));
        }
      }

      return true;
    }

    return false;
  }

  Future<bool> deleteOrphanedTags(int tagId) async {
    int tagCount = await _database.getCount('file_tags', where: 'tagId = ?', whereArgs: [tagId.toString()]);

    if (tagCount == 0) {
      _database.delete('tags', where: 'id = ?', whereArgs: [tagId.toString()]);
      return true;
    }

    return false;
  }

  Future<int> getEntityId(Entity entity) async {
    if (entity.id == null) {
      List<Map<String, dynamic>> results = await _database.query('files', columns: ['id'], where: 'path = ?', whereArgs: [entity.path]);
      if (results.isNotEmpty) {
        entity.id = results.first['id'];
      } else {
        entity.id = await _database.insert('files', entity.toMap());
      }
    }
    
    return entity.id!;
  }
  
  Future<int> getTagId(Tag tag) async {
    if (tag.id == null) {
      List<Map> tagRecords = await _database.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
      if (tagRecords.isNotEmpty) {
        return tagRecords.first['id'] as int;
      }
      else {
        return await _database.insert('tags', tag.toMap());
      }
    }

    return tag.id!;
  }

  Future<List<Tag>> getTags() async {
    List<Map<String, dynamic>> results = await _database.query('tags', columns: ['id', 'tag'], orderBy: 'tag');
    return results.map((row) => Tag.fromMap(row)).toList();
  }
  
  Future<Set<int>> getTagIdsForEntity(Entity entity) async {
    List<Map<String, dynamic>> results = await _database.query('file_tags', columns: ['tagId'], where: 'fileId = ?', whereArgs: [entity.id.toString()]);
    return results.map((row) => row.values.first).whereType<int>().toSet();
  }

  Future<bool> removeTagForEntity(Entity entity, int tagId) async {
    int id = await getEntityId(entity);

    // remove the tags for that file
    await _database.delete('file_tags', where: 'fileId = ? and tagId = ?', whereArgs: [id.toString(), tagId.toString()]);

    // Check for Orphaned tags
    return await deleteOrphanedTags(tagId);
  }

  Future<void> removeTagsForEntity(Entity entity, { bool deleteEntity = true }) async {
    // Given a file, get the fileId first.
    int id = await getEntityId(entity);

    // Get the tags related to that EntityId
    Set<int> tags = await getTagIdsForEntity(entity);

    // remove the tags for that file
    await _database.delete('file_tags', where: 'fileId = ?', whereArgs: [id.toString()]);

    // check to see if any of those tags are now orphaned
    bool refreshState = false;
    for (int tagId in tags) {
      bool deleted = await deleteOrphanedTags(tagId);
      if (deleted) {
        refreshState = true;
      }
    }

    // finally remove the actual entity from the database, if we are deleting it.
    if (deleteEntity) {
      await _database.delete('files', where: 'path = ?', whereArgs: [entity.path]);
    }

    // Rebuild the state if we have modified the list of tags.
    if (refreshState) {
      state = AsyncData(await getTags());
    }
  }

  Future<void> writeTags(Entity entity) async {
    bool refreshState = false;

    // Get the id for the FSE
    entity.id = await getEntityId(entity);

    // Delete any tags that have been removed.
    Set<int> storedEntityTagIds = await getTagIdsForEntity(entity);
    Set<int> entityTagIds = entity.tags.map((tag) => tag.id).whereType<int>().toSet();
    for (var tagId in storedEntityTagIds) {
      if (!entityTagIds.contains(tagId)) {
        refreshState = await removeTagForEntity(entity, tagId);
      }
    }

    // Insert all the Tags, updating the id for the next foreign key
    if (entity.tags.isNotEmpty) {
      for (var tag in entity.tags) {
        if (tag.tag.isEmpty) continue;

        tag.id = await getTagId(tag);
        refreshState = true;

        // We have a race condition here - if we create a new tag for multiple files, the second insert can fail before the query above returns the correct id.
        // I am sure there is a more elegant solution, but for now...
        if (tag.id == 0) {
          tag.id = await getTagId(tag);
        }

        List<Map> fileTagRecords = await _database.query('file_tags', columns: ['tagId'], where: 'tagId = ? and fileId = ?', whereArgs: [tag.id, entity.id]);
        if (fileTagRecords.isEmpty) {
          await _database.insert('file_tags', { 'tagId': tag.id, 'fileId': entity.id});
        }
      }
    }

    if (refreshState) {
      state = AsyncData(await getTags());
    }
  }
}