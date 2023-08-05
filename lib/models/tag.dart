import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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