import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../interfaces/file_events_callback.dart';
import '../../../models/file_of_interest.dart';
import 'grid_contents.dart';
import 'selected_grid_entities.dart';

part 'pane_contents.g.dart';

@Riverpod(keepAlive: true)
class PaneContents extends _$PaneContents implements FileEventsCallback {
  @override
  List<FileOfInterest> build() {
    List<FileOfInterest> selectedEntities = ref.watch(selectedGridEntitiesProvider);
    List<FileOfInterest> gridEntities = ref.watch(gridContentsProvider);
    List<FileOfInterest> sortedEntities = selectedEntities.isNotEmpty ? selectedEntities : gridEntities;

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

  @override
  void remove(FileOfInterest entity) {
    if (state.contains(entity)) {
      state = [
        for (var e in state)
          if (e.path != entity.path)
            e
      ];
    }
  }

  void removeAll() {
    state = [];
  }

  int size() {
    return state.length;
  }
}
