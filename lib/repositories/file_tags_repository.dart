import 'dart:io';

import '../database/app_database.dart';
import '../models/entity.dart';
import '../models/tag.dart';

class FileTagsRepository {
  late AppDatabase db;
  Map<String, Set<String>> cachedTags = {};

  // I know Riverpod says that we should not be using Singletons, but the provider pattern keeps creating
  // new instances. If someone can tell me what I am doing wrong, I'd appreciate it.
  FileTagsRepository._privateConstructor();
  static final FileTagsRepository _instance = FileTagsRepository._privateConstructor();
  factory FileTagsRepository(AppDatabase db) {
    _instance.db = db;
    return _instance;
  }

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

  Future<void> getTags() async {

  }

  Future<void> writeTags(FileSystemEntity entity, Set<Tag> tags) async {
    // Insert all the Tags, updating the id for the next foreign key
    if (tags.isNotEmpty) {
      for (var tag in tags) {
        List<Map> result = await db.query('tags', columns: ['id'], where: 'tag = ?', whereArgs: [tag.tag]);
        if (result.isNotEmpty) {
          tag.id = result.first['id'] as int;
        }
        else {
          tag.id = await db.insert('tags', tag.toMap());
        }
      }

      // Get the id for the FSE
      int entityId = -1;
      List<Map> result = await db.query('files', columns: ['id', 'path'], where: 'path = ?', whereArgs: [entity.path]);
      if (result.isNotEmpty) {
        entityId = result.first['id'];
      } else {
        entityId = await db.insert('files', Entity(path: entity.path).toMap());
      }

      // Insert the many-many relationship into file_tags.
      for (var tag in tags) {
        List<Map> result = await db.query('file_tags', columns: ['tagId'], where: 'tagId = ? and fileId = ?', whereArgs: [tag.id, entityId]);
        if (result.isEmpty) {
          db.insert('file_tags', { 'tagId': tag.id, 'fileId': entityId});
        }
      }
    }
  }

}