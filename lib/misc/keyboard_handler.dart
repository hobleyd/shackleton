import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardHandler {
  bool _isIndividualMultiSelectionPressed = false;
  bool _isBlockMultiSelectionPressed = false;
  bool _hasFocus = false;

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (!_hasFocus) {
      return KeyEventResult.ignored;
    }

    // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
    // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
    bool isCtrlOrMeta = event is RawKeyDownEvent
        ? (Platform.isMacOS && event.isMetaPressed) || (!Platform.isMacOS && event.isControlPressed)
        : (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight))
        ||
        (!Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight));

    if (event is RawKeyDownEvent) {
      if (isCtrlOrMeta) {
        _isIndividualMultiSelectionPressed = true;

        if (event.physicalKey == PhysicalKeyboardKey.keyA) {
          var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
          selectedEntities.addAll(entities.toSet());
        }

        return KeyEventResult.handled;
      } else if (event.isShiftPressed) {
        _isBlockMultiSelectionPressed = true;

        return KeyEventResult.handled;
      }
    } else if (event is RawKeyUpEvent) {
      if (isCtrlOrMeta) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        _isIndividualMultiSelectionPressed = false;

        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _isBlockMultiSelectionPressed = false;

        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void deregister() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);
  }

  void register() {
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }
}