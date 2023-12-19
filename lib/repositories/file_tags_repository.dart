import 'dart:collection';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:synchronized/synchronized.dart';

import '../database/app_database.dart';
import '../models/entity.dart';
import '../models/tag.dart';
import '../providers/tag_queue.dart';

part 'file_tags_repository.g.dart';

@riverpod
class FileTagsRepository extends _$FileTagsRepository {
  late AppDatabase _database;
  final _lock = Lock();

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

    var queue = ref.watch(tagQueueProvider);
    pop(queue);

    return getTags();
  }

  Future<List<Tag>> getTags() async {
    List<Map<String, dynamic>> results = await _database.query('tags', columns: ['id', 'tag'], orderBy: 'tag');
    return results.map((row) => Tag.fromMap(row)).toList();
  }

  Future<void> pop(Queue<Entity> queue) async {
    await _lock.synchronized(() async {
      while (queue.isNotEmpty) {
        Entity entity = queue.removeFirst();
        if (entity.hasTags) {
          await writeTags(entity);
        } else {
          await removeTags(entity);
        }
      }
    });
  }

  Future<int> removeTags(entity) async {
    return await _database.delete('file_tags', where: 'fileId = ?', whereArgs: [entity.path]);
    // TODO: clean up the dangling tags, if there are any
  }

  Future<void> writeTags(Entity entity) async {
    // Get the id for the FSE
    List<Map<String, dynamic>> result = await _database.query('files', columns: ['id'], where: 'path = ?', whereArgs: [entity.path]);
    if (result.isNotEmpty) {
      entity.id = result.first['id'];
    } else {
      entity.id = await _database.insert('files', entity.toMap());
    }

    // Insert all the Tags, updating the id for the next foreign key
    if (entity.tags.isNotEmpty) {
      for (var tag in entity.tags) {
        if (tag.tag.isEmpty) continue;

        List<Map> tagRecords = await _database.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
        if (tagRecords.isNotEmpty) {
          tag.id = tagRecords.first['id'] as int;
        }
        else {
          tag.id = await _database.insert('tags', tag.toMap());
        }

        List<Map> fileTagRecords = await _database.query('file_tags', columns: ['tagId'], where: 'tagId = ? and fileId = ?', whereArgs: [tag.id, entity.id]);
        if (fileTagRecords.isEmpty) {
          await _database.insert('file_tags', { 'tagId': tag.id, 'fileId': entity.id});
        }
      }
    }
  }
}