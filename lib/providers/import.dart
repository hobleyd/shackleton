import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import '../models/import_entity.dart';

part 'import.g.dart';

@riverpod
class Import extends _$Import {
  List<ImportEntity> _importEntities = [];

  @override
  Future<List<ImportEntity>> build(Set<FileOfInterest> entities) async {
    return _traverseEntities(entities);
  }

  Future<List<ImportEntity>> _processEntity(FileOfInterest entity) async {
    List<ImportEntity> entities = [];

    if (entity.isDirectory) {
      Directory d = entity.entity as Directory;
      for (var entity in d.listSync()) {
        entities.addAll(await _processEntity(FileOfInterest(entity: entity)));
      }
    } else if (entity.isFile) {
      ImportEntity e = ImportEntity(fileToImport: entity);
      await e.getPathInLibrary();
      entities.add(e);
    }

    _importEntities = List.from(entities);
    return entities;
  }

  Future<List<ImportEntity>> _traverseEntities(Set<FileOfInterest> entities) async {
    List<ImportEntity> files = [];

    for (var entity in entities) {
      files.addAll(await _processEntity(entity));
    }

    return files;
  }

  void replace(ImportEntity entity, ImportEntity replacement) async {
    _importEntities[_importEntities.indexOf(entity)] = replacement;
    state = await AsyncValue.guard(() async => _importEntities);
  }
}