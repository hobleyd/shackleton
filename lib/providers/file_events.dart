import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../interfaces/file_events_callback.dart';
import '../models/entity.dart';
import '../models/file_of_interest.dart';

part 'file_events.g.dart';

@Riverpod(keepAlive: true)
class FileEvents extends _$FileEvents {
  @override
  List<FileEventsCallback> build() {
    return [];
  }

  void delete(FileOfInterest entity, { required bool deleteEntity }) {
    if (entity.isDirectory) {
      if (entity.exists) {
        Directory d = entity.entity as Directory;
        for (var file in d.listSync()) {
          delete(FileOfInterest(entity: file), deleteEntity: deleteEntity);
        }
      }
    }

    for (var callback in state) {
      callback.remove(entity);
    }

    if (entity.exists && deleteEntity) {
      entity.delete();
      // We also need to clean up the filetags cache in the database.
      final filetags = ref.read(fileTagsRepositoryProvider.notifier);
      filetags.removeTagsForEntity(Entity(path: entity.path));
    }
  }

  void deleteAll(Set<FileOfInterest> entities) {
    for (var e in entities) {
      delete(e, deleteEntity: true);
    }
  }

  void register(FileEventsCallback callback) {
    if (!state.contains(callback)) {
      state = [...state, callback];
    }
  }
}
