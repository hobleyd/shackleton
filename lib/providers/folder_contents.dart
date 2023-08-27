import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import '../misc/utils.dart';
import '../providers/selected_entities.dart';
import 'folder_settings.dart';

part 'folder_contents.g.dart';

enum EntitySortField { name, size, modified }
enum EntitySortOrder { asc, desc }

@riverpod
class FolderContents extends _$FolderContents {
  EntitySortField defaultSort = EntitySortField.name;
  EntitySortOrder defaultSortOrder = EntitySortOrder.asc;

  @override
  List<FileOfInterest> build(Directory path) {
    var folderSettings = ref.watch(folderSettingsProvider(path));

    getFolderContents(path, folderSettings.showHiddenFiles);
    watchFolder(path);
    return state;
  }

  void add(FileOfInterest entity) {
    List<FileOfInterest> entities = [...state, entity];
    state = [...sort(entities, defaultSort)];
  }

  void getFolderContents(Directory path, bool showHiddenFiles) {
    List<FileOfInterest> files = [];
    for (var file in path.listSync()) {
      FileOfInterest foi = FileOfInterest(entity: file);
      if (!showHiddenFiles && foi.isHidden) {
          continue;
      }
      files.add(foi);
    }
    state = [...sort(files, defaultSort)];
  }

  void setEditableState(FileOfInterest entity, bool editable) {
    List<FileOfInterest> files = List.from(state);
    int idx = files.indexOf(entity);
    files.removeAt(idx);
    files.insert(idx, entity.copyWith(editing: editable));
    state = files;
  }

  List<FileOfInterest> sort(List<FileOfInterest> entities, EntitySortField sortField) {
    var _ = switch (sortField) {
      EntitySortField.name => defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last))
          : entities.sort((b, a) => a.path.split('/').last.compareTo(b.path.split('/').last)),
      EntitySortField.size => defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.stat.size.compareTo(b.stat.size))
          : entities.sort((b, a) => a.stat.size.compareTo(b.stat.size)),
      EntitySortField.modified => defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.stat.modified.compareTo(b.stat.modified))
          : entities.sort((b, a) => a.stat.modified.compareTo(b.stat.modified))
    };

    return entities;
  }

  void sortBy(EntitySortField sortField) {
    if (sortField == defaultSort) {
      defaultSortOrder = defaultSortOrder == EntitySortOrder.asc ? EntitySortOrder.desc : EntitySortOrder.asc;
    } else {
      defaultSort = sortField;
    }
    state = [...sort(state, defaultSort)];
  }

  void watchFolder(Directory path) async {
    Stream<FileSystemEvent> events = path.watch(events: FileSystemEvent.all);
    events.listen((FileSystemEvent event) {
      switch (event.type) {
        case FileSystemEvent.create:
          FileOfInterest foi = FileOfInterest(entity: getEntity(event.path));
          if (!state.contains(foi)) {
            if (!foi.isHidden) {
              add(foi);
            }
          }
          break;
        case FileSystemEvent.delete:
        case FileSystemEvent.move:
          var folderEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
          var previewEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
          FileOfInterest foi = FileOfInterest(entity: getEntity(event.path));

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
