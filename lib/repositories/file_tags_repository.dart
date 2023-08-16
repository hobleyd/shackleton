import 'dart:collection';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/tag_queue.dart';
import 'package:synchronized/synchronized.dart';

import '../database/app_database.dart';
import '../models/entity.dart';

part 'file_tags_repository.g.dart';

@riverpod
class FileTagsRepository extends _$FileTagsRepository {
  final _lock = Lock();

  static const String tableName = 'app_settings';
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
  AppDatabase build(AppDatabase db) {
    var queue = ref.watch(tagQueueProvider);
    pop(db, queue);
    return db;
  }

  Future<void> getTags() async {

  }

  Future<void> pop(AppDatabase db, Queue<Entity> queue) async {
    await _lock.synchronized(() async {
      if (queue.isNotEmpty) {
        Entity entity = queue.removeFirst();
        if (entity.tags.isNotEmpty) {
          await writeTags(db, entity);
        }
      }
    });
  }

  Future<void> writeTags(AppDatabase db, Entity entity) async {
    // Get the id for the FSE
    List<Map<String, dynamic>> result = await db.query('files', columns: ['id'], where: 'path = ?', whereArgs: [entity.path]);
    if (result.isNotEmpty) {
      entity.id = result.first['id'];
    } else {
      entity.id = await db.insert('files', entity.toMap());
    }

    // TODO: how do I remove all tags?
    // Insert all the Tags, updating the id for the next foreign key
    if (entity.tags.isNotEmpty) {
      for (var tag in entity.tags) {
        if (tag.tag.isEmpty) continue;

        List<Map> tagRecords = await db.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
        if (tagRecords.isNotEmpty) {
          tag.id = tagRecords.first['id'] as int;
        }
        else {
          tag.id = await db.insert('tags', tag.toMap());
        }

        List<Map> fileTagRecords = await db.query('file_tags', columns: ['tagId'], where: 'tagId = ? and fileId = ?', whereArgs: [tag.id, entity.id]);
        if (fileTagRecords.isEmpty) {
          await db.insert('file_tags', { 'tagId': tag.id, 'fileId': entity.id});
        }
      }
    }
  }

}