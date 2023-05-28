import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'entity.dart';

class Tag extends Comparable {
  int? id;
  String tag;

  Tag({
    this.id,
    required this.tag,
  });

  @override
  int compareTo(other) => tag.compareTo(other.tag);

  @override
  get hashCode => tag.hashCode;

  @override
  bool operator ==(other) => other is Tag && tag == other.tag;

  static Future<List<Tag>> getTags(Database db, FileSystemEntity entity) async {
    final List<Map<String, dynamic>> maps = await db.rawQuery('select tags.id, tags.tag from file_tags, tags, files where file_tags.fileId = files.id and files.tagId = tags.id and files.path = ?', [entity.path]);
    return List.generate(maps.length, (i) {
      return fromMap(maps[i]);
    });
  }

  static Future<void> writeTags(Database db, FileSystemEntity entity, List<Tag> tags) async {
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
      int entityId = await db.insert('files', Entity(path: entity.path).toMap(), conflictAlgorithm: ConflictAlgorithm.replace);

      // Insert the many-many relationship into file_tags.
      for (var tag in tags) {
        List<Map> result = await db.query('file_tags', columns: ['tagId'], where: 'tagId = ? and fileId = ?', whereArgs: [tag.id, entityId]);
        if (result.isEmpty) {
          db.insert('file_tags', { 'tagId': tag.id, 'fileId': entityId});
        }
      }
    }
  }

  static Tag fromMap(Map<String, dynamic> tag) {
    return Tag(
      id: tag['id'],
      tag: tag['tag'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag': tag,
    };
  }

  @override
  String toString() {
    return tag;
  }
}