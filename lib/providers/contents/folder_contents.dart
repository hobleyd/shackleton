import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_of_interest.dart';
import '../file_events.dart';

part 'folder_contents.g.dart';

enum EntitySortField { name, size, modified }
enum EntitySortOrder { asc, desc }

@riverpod
class FolderContents extends _$FolderContents {
  EntitySortField _defaultSort = EntitySortField.name;
  EntitySortOrder _defaultSortOrder = EntitySortOrder.asc;

  @override
  List<FileOfInterest> build(Directory path) {
    watchFolder(path);

    return getFolderContents(path);
  }

  void add(FileOfInterest entity) {
    List<FileOfInterest> entities = [...state, entity];
    state = [...sort(entities, _defaultSort)];
  }

  void delete(String path, FileOfInterest entity) {
    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.delete(entity, deleteEntity: false); // Already deleted, just cleaning up here.

    state = [
      for (final element in state)
        if (element.path != path) element,
    ];
  }

  List<FileOfInterest> getFolderContents(Directory path) {
    List<FileOfInterest> files = [];
    for (var file in path.listSync()) {
      files.add(FileOfInterest(entity: file));
    }

    return sort(files, _defaultSort);
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
    state = sort(List.from(state), _defaultSort);
  }

  void watchFolder(Directory path) async {
    Stream<FileSystemEvent> events = path.watch(events: FileSystemEvent.all);
    events.listen((FileSystemEvent event) {
      FileOfInterest foi = FileOfInterest(entity: event.isDirectory ? Directory(event.path) : File(event.path));
      // Windows provides out of order file system events; so let's use a sledgehammer.
      if (Platform.isWindows) {
        if (foi.isFile) {
          List<FileOfInterest> files = [];
          for (var file in foi.entity.parent.listSync()) {
            files.add(FileOfInterest(entity: file));
          }
          List<FileOfInterest> toAdd = files.where((i) => !state.contains(i)).toList();
          List<FileOfInterest> toDelete = state.where((i) => !files.contains(i)).toList();
          // Look for files not in the current state, to add
          // Look for files not in the modified list, to delete
          List<FileOfInterest> entities = [...state, ...toAdd];
          entities.removeWhere((i) => toDelete.contains(i));
          state = [...sort(entities, _defaultSort)];
        }
      } else {
        // So if I unmount a folder from the filesystem, FileSystemEvent shows this as a file, not a directory. How frustrating. We can infer this instead...
        switch (event.type) {
          case FileSystemEvent.create:
          case FileSystemEvent.modify:
            if (!state.contains(foi)) {
              if (!foi.isHidden) {
                add(foi);
              }
            }
            break;
          case FileSystemEvent.delete:
            delete(event.path, foi);
            break;
          case FileSystemEvent.move:
            FileSystemMoveEvent e = event as FileSystemMoveEvent;
            add(FileOfInterest(entity: e.isDirectory ? Directory(e.destination!) : File(e.destination!)));
            delete(event.path, foi);
            break;
        }
      }
    });
  }
}
