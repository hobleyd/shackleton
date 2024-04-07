import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../interfaces/file_events_callback.dart';
import '../../models/file_of_interest.dart';
import '../../providers/file_events.dart';

part 'selected_grid_entities.g.dart';

@Riverpod(keepAlive: true)
class SelectedGridEntities extends _$SelectedGridEntities implements FileEventsCallback {
  @override
  List<FileOfInterest> build() {
    Future(() {
      register();
    });

    return [];
  }

  void add(FileOfInterest entity) {
    if (!state.contains(entity)) {
      state.add(entity);
      state.sort();

      state = List.from(state);
    }
  }

  void addAll(Set<FileOfInterest> entities) {
    Set<FileOfInterest> entitySet = { ...state, ...entities };
    List<FileOfInterest> newState = List.from(entitySet);
    newState.sort();

    state = newState;
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
          if (e.path != entity.path)
            e
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
    List<FileOfInterest> newState = List.from(entities);
    newState.sort();

    state = newState;
  }

  int size() {
    return state.length;
  }
}
