import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import '../misc/utils.dart';
import '../providers/selected_entities.dart';

part 'folder_contents.g.dart';

@riverpod
class FolderContents extends _$FolderContents {
  @override
  List<FileOfInterest> build(Directory path) {
    getFolderContents(path);
    watchFolder(path);
    return state;
  }

  void getFolderContents(Directory path) {
    // TODO: refactor with AppSettings.
    bool showHiddenFiles = false;

    List<FileOfInterest> files = [];
    for (var file in path.listSync()) {
      FileOfInterest foi = FileOfInterest(entity: file);
      if (!showHiddenFiles && foi.isHidden) {
          continue;
      }
      files.add(foi);
    }
    state = [...sort(files)];
  }

  List<FileOfInterest> sort(List<FileOfInterest> entities) {
    entities.sort((a, b) =>
        a.path.split('/').last.compareTo(b.path.split('/').last));
    return entities;
  }

  void watchFolder(Directory path) async {
    Stream<FileSystemEvent> events = path.watch(events: FileSystemEvent.all);
    events.listen((FileSystemEvent event) {
      switch (event.type) {
        case FileSystemEvent.create:
          FileOfInterest foi = getEntity(event.path);
          if (!state.contains(foi)) {
            if (!foi.isHidden) {
              List<FileOfInterest> entities = [...state, foi];
              state = [...sort(entities)];
            }
          }
          break;
        case FileSystemEvent.delete:
        case FileSystemEvent.move:
          var folderEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
          var previewEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
          FileOfInterest foi = getEntity(event.path);

          if (folderEntities.contains(foi)) {
            folderEntities.remove(foi);
          }

          if (previewEntities.contains(foi)) {
            previewEntities.remove(foi);
          }

          state = [
            for (final element in state)
              if (element.path != event.path) element,
          ];
          break;
      }
    });
  }
}
