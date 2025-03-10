import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../providers/editing_entity.dart';
import '../../providers/file_events.dart';
import '../../providers/folder_path.dart';
import '../../providers/metadata.dart';

class FolderPaneController implements KeyboardCallback {
  final BuildContext context;
  final WidgetRef ref;
  final Directory path;

  late List<FileOfInterest> folderEntities;
  late KeyboardHandler keyHandler;
  late ValueSetter<int> visibilityCallback;

  int _startSelectedItemIndex = -1;
  int _endSelectedItemIndex = -1;
  int _lastSelectedItemIndex = -1;
  int _lastSelectedTimestamp = -1;

  FolderPaneController({ required this.context, required this.ref, required this.path }) {
    keyHandler = KeyboardHandler(ref: ref, keyboardCallback: this, name: 'FolderPaneController');
    keyHandler.register();
  }

  set hasFocus(bool hasFocus) => keyHandler.hasFocus = hasFocus;
  set isEditing(bool isEditing) => keyHandler.isEditing = isEditing;

  @override
  void delete() {
    Set<FileOfInterest> selectedEntities = ref.read(selectedFolderContentsProvider);

    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.deleteAll(selectedEntities.toSet());
  }

  void deregister() {
    keyHandler.deregister();
  }

  @override
  void down() {
    List<FileOfInterest> entities = ref.read(folderContentsProvider(path.path));

    if (_lastSelectedItemIndex < entities.length - 1) {
      int lastIdx = _lastSelectedItemIndex + 1;

      if (keyHandler.isBlockMultiSelectionPressed) {
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

      _lastSelectedTimestamp = -1;

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  @override
  void exit() {
    if (keyHandler.isEditing) {
      FileOfInterest? entity = ref.read(editingEntityProvider);
      if (entity != null) {
        ref.read(editingEntityProvider.notifier).setEditingEntity(entity.path, null);
        keyHandler.isEditing = false;
      }
    }
  }

  @override
  void left() {}

  @override
  void newEntity() {
    FolderContents contents = ref.read(folderContentsProvider(path.path).notifier);
    FileOfInterest entity = FileOfInterest(entity: path.createTempSync('new-'), editing: true);
    contents.add(entity);
    keyHandler.isEditing = true;
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

      if (keyHandler.isBlockMultiSelectionPressed) {
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

      _lastSelectedTimestamp = -1;

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  void selectEntity(int idx) {
    FileOfInterest entity = folderEntities[idx];
    _lastSelectedItemIndex = idx;

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    // Add the selected Directory into the visible folder list.
    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(path, entity.entity as Directory);
    }

    var selectedFolderContents = ref.read(selectedFolderContentsProvider.notifier);
    if (keyHandler.isIndividualMultiSelectionPressed) {
      selectedFolderContents.contains(entity) ? selectedFolderContents.remove(entity) : selectedFolderContents.add(entity);
    } else if (keyHandler.isBlockMultiSelectionPressed) {
      if (_lastSelectedItemIndex != -1) {
        Set<FileOfInterest> newSelection = {};
        for (int i = _startSelectedItemIndex; i <= _endSelectedItemIndex; i++) {
          newSelection.add(folderEntities[i]);
        }
        ref.read(selectedFolderContentsProvider.notifier).replaceAll(newSelection);
      }
    } else {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (_lastSelectedItemIndex == idx) {
        if (currentTimestamp - _lastSelectedTimestamp < 2000) {
            ref.read(editingEntityProvider.notifier).setEditingEntity(path, entity);
            keyHandler.isEditing = true;
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
      _lastSelectedTimestamp = currentTimestamp;
    }
  }

  void selectEntityByMouse(int idx) {
    if (keyHandler.isBlockMultiSelectionPressed) {
      if (idx < _startSelectedItemIndex) {
        _startSelectedItemIndex = idx;
      } else {
        _endSelectedItemIndex = idx;
      }
    }

    selectEntity(idx);
  }
}