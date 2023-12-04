import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import '../providers/file_events.dart';

part 'folder_contents.g.dart';

enum EntitySortField { name, size, modified }
enum EntitySortOrder { asc, desc }

@Riverpod(keepAlive: true)
class FolderContents extends _$FolderContents {
  EntitySortField _defaultSort = EntitySortField.name;
  EntitySortOrder _defaultSortOrder = EntitySortOrder.asc;

  @override
  List<FileOfInterest> build(Directory path) {
    getFolderContents(path);
    watchFolder(path);
    return state;
  }

  void add(FileOfInterest entity) {
    List<FileOfInterest> entities = [...state, entity];
    state = [...sort(entities, _defaultSort)];
  }

  void getFolderContents(Directory path) {
    List<FileOfInterest> files = [];
    for (var file in path.listSync()) {
      files.add(FileOfInterest(entity: file));
    }
    state = [...sort(files, _defaultSort)];
  }

  EntitySortField getSortField() {
    return _defaultSort;
  }

  EntitySortOrder getSortOrder() {
    return _defaultSortOrder;
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
      EntitySortField.name => _defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last))
          : entities.sort((b, a) => a.path.split('/').last.compareTo(b.path.split('/').last)),
      EntitySortField.size => _defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.stat.size.compareTo(b.stat.size))
          : entities.sort((b, a) => a.stat.size.compareTo(b.stat.size)),
      EntitySortField.modified => _defaultSortOrder == EntitySortOrder.asc
          ? entities.sort((a, b) => a.stat.modified.compareTo(b.stat.modified))
          : entities.sort((b, a) => a.stat.modified.compareTo(b.stat.modified))
    };

    return entities;
  }

  void sortBy(EntitySortField sortField) {
    if (sortField == _defaultSort) {
      _defaultSortOrder = _defaultSortOrder == EntitySortOrder.asc ? EntitySortOrder.desc : EntitySortOrder.asc;
    } else {
      _defaultSort = sortField;
    }
    state = [...sort(state, _defaultSort)];
  }

  void watchFolder(Directory path) async {
    Stream<FileSystemEvent> events = path.watch(events: FileSystemEvent.all);
    events.listen((FileSystemEvent event) {
      // So if I unmount a folder from the filesystem, FileSystemEvent shows this as a file, not a directory. How frustrating. We can infer this instead...
      FileOfInterest foi = FileOfInterest(entity: event.path == path.path ? Directory(event.path) : File(event.path));
      switch (event.type) {
        case FileSystemEvent.create:
          if (!state.contains(foi)) {
            if (!foi.isHidden) {
              add(foi);
            }
          }
          break;
        case FileSystemEvent.delete:
        case FileSystemEvent.move:
          var fileEvents = ref.read(fileEventsProvider.notifier);
          fileEvents.delete(foi, deleteEntity: false); // Already deleted, just cleaning up here.

          state = [
            for (final element in state)
              if (element.path != event.path) element,
          ];
          break;
      }
    });
  }
}
