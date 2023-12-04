import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../interfaces/file_events_callback.dart';
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
    }
  }

  void deleteAll(Set<FileOfInterest> entities) {
    for (var e in entities) {
      delete(e, deleteEntity: true);
    }
  }

  void register(FileEventsCallback callback) {
    state = [...state, callback];
  }
}
