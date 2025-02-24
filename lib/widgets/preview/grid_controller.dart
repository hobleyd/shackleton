import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/file_events.dart';
import '../../providers/metadata.dart';

class GridController implements KeyboardCallback {
  final BuildContext context;
  final WidgetRef ref;

  late KeyboardHandler keyHandler;
  late ValueSetter<int> visibilityCallback;

  int gridColumns = 5;
  int _startSelectedItemIndex = -1;
  int _endSelectedItemIndex = -1;
  int _lastSelectedItemIndex = -1;

  GridController({ required this.context, required this.ref, }) {
    keyHandler = KeyboardHandler(ref: ref, keyboardCallback: this, name: 'PreviewGrid');
    keyHandler.register();
  }

  set hasFocus(bool hasFocus) => keyHandler.hasFocus = hasFocus;

  void deregister() {
    keyHandler.deregister();
  }

  @override
  void delete() {
    List<FileOfInterest> selectedEntities = ref.read(selectedGridEntitiesProvider);

    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.deleteAll(selectedEntities.toSet());
  }

  @override
  void down() {
    List<FileOfInterest> entities = ref.read(gridContentsProvider);

    int lastIdx = min(entities.length - 1, _lastSelectedItemIndex + gridColumns);
    if (keyHandler.isBlockMultiSelectionPressed) {
      if (lastIdx > _endSelectedItemIndex) {
        _endSelectedItemIndex = lastIdx;
      } else {
        _startSelectedItemIndex = lastIdx;
      }
    }
    selectEntity(lastIdx);

    visibilityCallback(lastIdx);
  }

  @override
  void exit() {
    Navigator.of(context, rootNavigator: true).maybePop(context);
  }

  @override
  void left() {
    if (_lastSelectedItemIndex > 0) {
      int lastIdx = _lastSelectedItemIndex - 1;

      if (keyHandler.isBlockMultiSelectionPressed) {
        if (lastIdx < _startSelectedItemIndex) {
          _startSelectedItemIndex = lastIdx;
        } else {
          _endSelectedItemIndex = lastIdx;
        }
      }

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  @override
  void right() {
    List<FileOfInterest> entities = ref.read(gridContentsProvider);

    if (_lastSelectedItemIndex < entities.length - 1) {
      int lastIdx = _lastSelectedItemIndex + 1;

      if (keyHandler.isBlockMultiSelectionPressed) {
        if (lastIdx > _endSelectedItemIndex) {
          _endSelectedItemIndex = lastIdx;
        } else {
          _startSelectedItemIndex = lastIdx;
        }
      }

      selectEntity(lastIdx);
      visibilityCallback(lastIdx);
    }
  }

  @override
  void newEntity() {

  }

  @override
  void selectAll() {
    List<FileOfInterest> entities = ref.read(gridContentsProvider);
    var entitiesNotifier = ref.read(selectedGridEntitiesProvider.notifier);

    entitiesNotifier.addAll(entities.toSet());
  }

  void selectEntity(int idx) {
    List<FileOfInterest> entities = ref.read(gridContentsProvider);
    FileOfInterest entity = entities[idx];
    _lastSelectedItemIndex = idx;

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    var entityNotifier = ref.read(selectedGridEntitiesProvider.notifier);
    if (keyHandler.isIndividualMultiSelectionPressed) {
      entityNotifier.contains(entity) ? entityNotifier.remove(entity) : entityNotifier.add(entity);
    } else if (keyHandler.isBlockMultiSelectionPressed) {
      if (_lastSelectedItemIndex != -1) {
        Set<FileOfInterest> newSelection = {};
        for (int i = _startSelectedItemIndex; i <= _endSelectedItemIndex; i++) {
          newSelection.add(entities[i]);
        }
        entityNotifier.replaceAll(newSelection);
      }
    } else {
      _startSelectedItemIndex = idx;
      _endSelectedItemIndex = idx;
      entityNotifier.replace(entity);
    }
  }

  @override
  void up() {
    int lastIdx = max(0, _lastSelectedItemIndex - gridColumns);

    if (keyHandler.isBlockMultiSelectionPressed) {
      if (lastIdx < _startSelectedItemIndex) {
        _startSelectedItemIndex = lastIdx;
      } else {
        _endSelectedItemIndex = lastIdx;
      }
    }

    selectEntity(lastIdx);
    visibilityCallback(lastIdx);
  }

}