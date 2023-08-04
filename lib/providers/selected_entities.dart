import 'dart:io';

import 'package:Shackleton/misc/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';

part 'selected_entities.g.dart';

enum FileType { folderList, previewGrid, previewPane }

@riverpod
class SelectedEntities extends _$SelectedEntities {
  @override
  Set<FileOfInterest> build(FileType type) {
    return {};
  }

  void add(FileOfInterest entity) {
    if (!state.contains(entity)) {
      state = { ...state, entity};
    }
  }

  void addAll(Set<FileOfInterest> entities) {
    state = { ...state, ...entities };
  }

  void clear() {
    state = {};
  }

  bool contains(FileOfInterest entity) {
    return state.contains(entity);
  }

  void delete(FileOfInterest entity) {
    entity.delete();
    remove(entity);
  }

  void deleteAll() {
    for (var e in state) {
      e.delete();
    }
    clear();
  }

  bool isSelected(FileOfInterest entity) {
    return state.contains(entity);
  }

  void remove(FileOfInterest entity) {
    if (state.contains(entity)) {
      state = {
        for (var e in state)
          if (e.path != entity.path)
            e
      };
    }
  }

  void replace(FileOfInterest entity) {
    state = { entity };
  }

  int size() {
    return state.length;
  }
}
