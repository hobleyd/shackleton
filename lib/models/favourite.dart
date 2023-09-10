import 'dart:io';

import 'package:path/path.dart';

class Favourite  {
  int? id;
  String path;
  String? name;
  int sortOrder;

  get directory => Directory(path);
  get uri => directory.uri;

  Favourite({
    required this.path,
    this.id,
    required this.sortOrder,
    this.name,
  }) {
    name ??= basename(path);
  }

  static Favourite fromMap(Map<String, dynamic> entity) {
    return Favourite(
      id: entity['id'],
      path: entity['path'],
      name: entity['name'],
      sortOrder: entity['sort_order'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'sort_order': sortOrder,
    };
  }

  @override
  String toString() {
    return '${basename(path)}: $id ($sortOrder)';
  }
}