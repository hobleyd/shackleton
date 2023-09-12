import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import '../models/import_entity.dart';

part 'import.g.dart';

@riverpod
class Import extends _$Import {
  @override
  Future<List<ImportEntity>> build(Set<FileOfInterest> entities) async {
    return _traverseEntities(entities);
  }

  Future<List<ImportEntity>> _processEntity(FileOfInterest entity) async {
    List<ImportEntity> files = [];

    if (entity.isDirectory) {
      Directory d = entity.entity as Directory;
      for (var entity in d.listSync()) {
        files.addAll(await _processEntity(FileOfInterest(entity: entity)));
      }
    } else if (entity.isFile) {
      ImportEntity e = ImportEntity(fileToImport: entity);
      await e.getPathInLibrary();
      files.add(e);
    }

    return files;
  }

  Future<List<ImportEntity>> _traverseEntities(Set<FileOfInterest> entities) async {
    List<ImportEntity> files = [];

    for (var entity in entities) {
      files.addAll(await _processEntity(entity));
    }

    return files;
  }
}