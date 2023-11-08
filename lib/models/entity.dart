import 'package:path/path.dart';
import 'package:shackleton/models/file_metadata.dart';

class Entity  {
  int? id;
  String path;
  FileMetaData? metadata;

  get hasTags => metadata?.hasTags;
  get tags => metadata?.tags;

  Entity({
    required this.path,
    this.id,
    this.metadata,
  });

  Entity copyWith({required Entity entity, FileMetaData? metadata}) {
    return Entity(
      id: entity.id,
      path: entity.path,
      metadata: metadata,
    );
  }

  static Entity fromMap(Map<String, dynamic> entity) {
    return Entity(
      id: entity['id'],
      path: entity['path'],
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
    return '${basename(path)}: $id ($metadata)';
  }
}