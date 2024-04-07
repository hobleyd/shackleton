import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/grid_contents.dart';
import 'package:shackleton/providers/selected_entities/selected_folder_contents.dart';
import 'package:shackleton/providers/selected_entities/selected_grid_entities.dart';

import '../../interfaces/file_events_callback.dart';
import '../../models/file_of_interest.dart';
import '../../providers/file_events.dart';

part 'pane_contents.g.dart';

@riverpod
class PaneContents extends _$PaneContents implements FileEventsCallback {
  @override
  List<FileOfInterest> build() {
    Future(() {
      register();
    });

    Set<FileOfInterest> entities = ref.watch(selectedGridEntitiesProvider);
    if (entities.isEmpty) {
      entities = ref.watch(gridContentsProvider);
    }
    List<FileOfInterest> sortedEntities = List.from(entities);
    sortedEntities.sort();

    return sortedEntities;
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
    state.remove(entity);
  }

  void removeAll() {
    state = [];
  }

  int size() {
    return state.length;
  }
}
