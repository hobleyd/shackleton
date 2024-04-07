import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../interfaces/file_events_callback.dart';
import '../../../models/file_of_interest.dart';
import '../../../providers/file_events.dart';
import 'selected_folder_contents.dart';

part 'grid_contents.g.dart';

@Riverpod(keepAlive: true)
class GridContents extends _$GridContents implements FileEventsCallback {
  @override
  List<FileOfInterest> build() {
    Future(() {
      register();
    });

    Set<FileOfInterest> entities = ref.watch(selectedFolderContentsProvider);
    List<FileOfInterest> gridEntities = [];

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
    gridEntities.sort();
    return gridEntities;
  }

  void add(FileOfInterest entity) {
    if (!state.contains(entity)) {
      state = [ ...state, entity ];
      state.sort();
    }
  }

  void addAll(Set<FileOfInterest> entities) {
    state = { ...state, ...entities }.toList();
    state.sort();
  }

  void clear() {
    state = [];
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
    if (state.contains(entity)) {
      state = [
        for (var e in state)
          if (e.path != entity.path) e
      ];
    }
  }

  void removeAll() {
    state = [];
  }

  void replace(FileOfInterest entity) {
    state = [ entity ];
  }

  void replaceAll(Set<FileOfInterest> entities) {
    state = List.from(entities);
    state.sort();
  }

  int size() {
    return state.length;
  }
}
