import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/selected_entities/selected_folder_contents.dart';

import '../../interfaces/file_events_callback.dart';
import '../../models/file_of_interest.dart';
import '../../providers/file_events.dart';

part 'grid_contents.g.dart';

@Riverpod(keepAlive: true)
class GridContents extends _$GridContents implements FileEventsCallback {
  @override
  Set<FileOfInterest> build() {
    Future(() {
      register();
    });

    Set<FileOfInterest> entities = ref.watch(selectedFolderContentsProvider);
    if (entities.isEmpty) {
      Set<FileOfInterest> gridEntities = {};

      for (var entity in entities) {
        if (entity.canPreview) {
          gridEntities.add(entity);
        } else if (entity.isDirectory) {
          Directory d = Directory(entity.path);
          for (var e in d.listSync()) {
            FileOfInterest foi = FileOfInterest(entity: e);
            if (foi.canPreview) {
              gridEntities.add(foi);
            }
          }
        }
      }
      return gridEntities;
    } else {
      return Set.from(entities);
    }
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

  bool isSelected(FileOfInterest entity) {
    return state.contains(entity);
  }

  Future<void> register() async {
    ref.read(fileEventsProvider.notifier).register(this);
  }

  @override
  void remove(FileOfInterest entity) {
    if (entity.isDirectory) {
      state = {
        for (var e in state)
          if (!e.path.startsWith(entity.path))
            e
      };
    } else {
      if (state.contains(entity)) {
        state = {
          for (var e in state)
            if (e.path != entity.path)
              e
        };
      }
    }
  }

  void removeAll() {
    state = {};
  }

  void replace(FileOfInterest entity) {
    state = { entity };
  }

  void replaceAll(Set<FileOfInterest> entities) {
    state = { ...entities };
  }

  int size() {
    return state.length;
  }
}
