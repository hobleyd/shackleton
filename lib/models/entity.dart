import 'package:path/path.dart';

import '../models/tag.dart';

class Entity  {
  int? id;
  String path;
  Set<Tag> tags;

  Entity({
    required this.path,
    this.id,
    required this.tags,
  });

  Entity copyWith({required Entity entity, Set<Tag>? tags}) {
    return Entity(
      id: entity.id,
      path: entity.path,
      tags: tags ?? {},
    );
  }

  static Entity fromMap(Map<String, dynamic> entity) {
    return Entity(
      id: entity['id'],
      path: entity['path'],
      tags: {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
    };
  }

  @override
  String toString() {
    return '${basename(path)}: $id ($tags)';
  }
}