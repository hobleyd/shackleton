import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../providers/editing_entity.dart';
import '../../providers/editing_timestamp.dart';
import '../../providers/file_events.dart';
import '../../providers/folder_path.dart';
import '../../providers/metadata.dart';

class FolderPaneController implements KeyboardCallback {
  final BuildContext context;
  final WidgetRef ref;
  final Directory path;

  late List<FileOfInterest> folderEntities;
  late ValueSetter<int> visibilityCallback;

  int _startSelectedItemIndex = -1;
  int _endSelectedItemIndex = -1;
  int _lastSelectedItemIndex = -1;

  FolderPaneController({ required this.context, required this.ref, required this.path });

  bool get _isShiftPressed => HardwareKeyboard.instance.isShiftPressed;
  bool get _isMultiSelectPressed =>
      HardwareKeyboard.instance.isMetaPressed || HardwareKeyboard.instance.isControlPressed;

  @override
  void delete() {
    Set<FileOfInterest> selectedEntities = ref.read(selectedFolderContentsProvider);

    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.deleteAll(selectedEntities.toSet());
  }

  @override
  void down() {
    List<FileOfInterest> entities = ref.read(folderContentsProvider(path.path));

    if (_lastSelectedItemIndex < entities.length - 1) {
      int lastIdx = _lastSelectedItemIndex + 1;

      if (_isShiftPressed) {
        if (lastIdx > _endSelectedItemIndex) {
          _endSelectedItemIndex = lastIdx;
        } else {
          _startSelectedItemIndex = lastIdx;
        }
      } else {
        if (lastIdx != _endSelectedItemIndex) {
          lastIdx = min(_endSelectedItemIndex + 1, entities.length - 1);
        }
      }

      ref.read(editingTimestampProvider(entities[lastIdx]).notifier).setLastClickTimestamp(-1);

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  @override
  void exit() {
    FileOfInterest? entity = ref.read(editingEntityProvider);
    if (entity != null) {
      ref.read(editingEntityProvider.notifier).setEditingEntity(entity, false);
    }
  }

  @override
  void left() {}

  @override
  void newEntity() {
    FolderContents contents = ref.read(folderContentsProvider(path.path).notifier);
    FileOfInterest entity = FileOfInterest(entity: path.createTempSync('new-'), editing: true);
    contents.add(entity);
  }

  @override
  void right() {}

  @override
  void selectAll() {
    List<FileOfInterest> entities = ref.read(folderContentsProvider(path.path));
    ref.read(selectedFolderContentsProvider.notifier).replaceAll(entities.toSet());
  }

  @override
  void up() {
    if (_lastSelectedItemIndex > 0) {
      int lastIdx = _lastSelectedItemIndex - 1;

      if (_isShiftPressed) {
        if (lastIdx < _startSelectedItemIndex) {
          _startSelectedItemIndex = lastIdx;
        } else {
          _endSelectedItemIndex = lastIdx;
        }
      } else {
        if (lastIdx != _startSelectedItemIndex) {
          lastIdx = max(_startSelectedItemIndex - 1, 0);
        }
      }

      List<FileOfInterest> entities = ref.read(folderContentsProvider(path.path));
      ref.read(editingTimestampProvider(entities[lastIdx]).notifier).setLastClickTimestamp(-1);

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  void selectEntity(int idx) {
    FileOfInterest entity = folderEntities[idx];
    _lastSelectedItemIndex = idx;

    ref.read(metadataProvider(entity).notifier).setEditable(false);

    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(path, entity.entity as Directory);
    }

    var selectedFolderContents = ref.read(selectedFolderContentsProvider.notifier);
    if (_isMultiSelectPressed) {
      selectedFolderContents.contains(entity) ? selectedFolderContents.remove(entity) : selectedFolderContents.add(entity);
    } else if (_isShiftPressed) {
      if (_lastSelectedItemIndex != -1) {
        Set<FileOfInterest> newSelection = {};
        for (int i = _startSelectedItemIndex; i <= _endSelectedItemIndex; i++) {
          newSelection.add(folderEntities[i]);
        }
        selectedFolderContents.replaceAll(newSelection);
      }
    } else {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      int lastTimestamp = ref.read(editingTimestampProvider(entity));
      if (_lastSelectedItemIndex == idx) {
        if (currentTimestamp - lastTimestamp < 2000) {
            ref.read(editingEntityProvider.notifier).setEditingEntity(entity, true);
        } else {
          _startSelectedItemIndex = idx;
          _endSelectedItemIndex = idx;
          selectedFolderContents.replace(entity);
        }
      } else {
        _startSelectedItemIndex = idx;
        _endSelectedItemIndex = idx;
        selectedFolderContents.replace(entity);
      }

      ref.read(editingTimestampProvider(entity).notifier).setLastClickTimestamp(currentTimestamp);
    }
  }

  void selectEntityByEntity(FileOfInterest entity) {
    int idx = folderEntities.indexOf(entity);
    _startSelectedItemIndex = idx;
    _endSelectedItemIndex = idx;

    var selectedFolderContents = ref.read(selectedFolderContentsProvider.notifier);
    selectedFolderContents.replace(entity);
  }

  void selectEntityByMouse(int idx) {
    if (_isShiftPressed) {
      if (idx < _startSelectedItemIndex) {
        _startSelectedItemIndex = idx;
      } else {
        _endSelectedItemIndex = idx;
      }
    }

    selectEntity(idx);
  }
}
