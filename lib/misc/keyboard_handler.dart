import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/keyboard_callback.dart';

class KeyboardHandler {
  bool isIndividualMultiSelectionPressed = false;
  bool isBlockMultiSelectionPressed = false;
  bool hasFocus = false;
  bool isEditing = false;
  KeyboardCallback keyboardCallback;
  WidgetRef ref;

  KeyboardHandler({required this.ref, required this.keyboardCallback});

  // Return true if Meta is pressed on the Mac, or Ctrl is pressed on everything else.
  // We are waiting on you, Asahi Linux team!
  bool _isCtrlOrMeta(RawKeyEvent event) {
    return event is RawKeyDownEvent
        ? (Platform.isMacOS && event.isMetaPressed) || (!Platform.isMacOS && event.isControlPressed)
        : (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight))
        ||
        (!Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight));
  }

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (!hasFocus) {
      return KeyEventResult.ignored;
    }

    bool isCtrlOrMeta = _isCtrlOrMeta(event);

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        keyboardCallback.exit();
        return KeyEventResult.handled;
      } else {
        // If we are editing, don't stuff around with the keyboard shortcuts.
        if (!isEditing) {
          if (isCtrlOrMeta) {
            isIndividualMultiSelectionPressed = true;

            if (event.physicalKey == PhysicalKeyboardKey.keyA) {
              keyboardCallback.selectAll();
            }

            return KeyEventResult.handled;
          } else if (event.isShiftPressed) {
            isBlockMultiSelectionPressed = true;

            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            keyboardCallback.left();

            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            keyboardCallback.right();

            return KeyEventResult.handled;
          } else if (event.logicalKey == LogicalKeyboardKey.backspace || event.logicalKey == LogicalKeyboardKey.delete) {
            keyboardCallback.delete();
            return KeyEventResult.handled;
          }
        }
      }
    } else if (event is RawKeyUpEvent) {
      if (isCtrlOrMeta) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        isIndividualMultiSelectionPressed = false;

        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
        isBlockMultiSelectionPressed = false;

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

  void setEditing(bool editing) {
    isEditing = editing;
  }
}