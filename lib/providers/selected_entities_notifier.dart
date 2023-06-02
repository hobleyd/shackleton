import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';

part 'selected_entities_notifier.g.dart';

enum FileType { folderList, previewGrid }

@riverpod
class SelectedEntitiesNotifier extends _$SelectedEntitiesNotifier {
  @override
  Set<FileOfInterest> build(FileType type) {
    return {};
  }

  void add(FileOfInterest entity) {
    if (!state.contains(entity)) {
      state = { ...state, entity};
    }
  }

  void clear() {
    state = {};
  }

  bool contains(FileOfInterest entity) {
    return state.contains(entity);
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

  int size() {
    return state.length;
  }
}
