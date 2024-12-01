import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/keyboard_callback.dart';

class KeyboardHandler {
  bool isIndividualMultiSelectionPressed = false;
  bool isBlockMultiSelectionPressed = false;
  bool processModifierKeys = true;
  bool hasFocus = false;
  bool isEditing = false;
  KeyboardCallback keyboardCallback;
  WidgetRef ref;
  String name;

  KeyboardHandler({required this.ref, required this.keyboardCallback, required this.name});

  // Return true if Meta is pressed on the Mac, or Ctrl is pressed on everything else.
  // We are waiting on you, Asahi Linux team!
  bool _isCtrlOrMeta(KeyEvent event) {
    return event is KeyDownEvent
        ? (Platform.isMacOS && HardwareKeyboard.instance.isMetaPressed) || (!Platform.isMacOS && HardwareKeyboard.instance.isControlPressed)
        : (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight))
        ||
        (!Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight));
  }

  bool _handleKeyEvent(KeyEvent event,) {
    if (!hasFocus) {
      // All Keyboard Handlers listen all the time, so we only want to react to the one in focus.
      return false;
    }
    
    bool isCtrlOrMeta = _isCtrlOrMeta(event);

    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        keyboardCallback.exit();
        return true;
      } else {
        // If we are editing, don't stuff around with the keyboard shortcuts.
        if (!isEditing) {
          if (isCtrlOrMeta) {
            isIndividualMultiSelectionPressed = true;

            if (event.physicalKey == PhysicalKeyboardKey.keyA) {
              keyboardCallback.selectAll();
            } else if (event.physicalKey == PhysicalKeyboardKey.keyN) {
              keyboardCallback.newEntity();
            }

            return true;
          } else if (processModifierKeys && HardwareKeyboard.instance.isShiftPressed) {
            if (event.logicalKey == LogicalKeyboardKey.tab) {
              isBlockMultiSelectionPressed = false;
              keyboardCallback.left();

              return true;
            } else {
              isBlockMultiSelectionPressed = true;

              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                keyboardCallback.left();
              } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                keyboardCallback.right();
              } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                keyboardCallback.up();
              } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                keyboardCallback.down();
              }

              return true;
            }
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            keyboardCallback.left();

            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight || event.logicalKey == LogicalKeyboardKey.tab) {
            keyboardCallback.right();

            return true;
          }  else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            keyboardCallback.up();

            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            keyboardCallback.down();

            return true;
          } else if (event.logicalKey == LogicalKeyboardKey.backspace || event.logicalKey == LogicalKeyboardKey.delete) {
            keyboardCallback.delete();
            return true;
          }
        }
      }
    } else if (event is KeyUpEvent) {
      if (isCtrlOrMeta) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        isIndividualMultiSelectionPressed = false;

        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
        isBlockMultiSelectionPressed = false;

        return true;
      }
    }

    return false;
  }

  void deregister() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
  }

  void register() {
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  void setEditing(bool editing) {
    isEditing = editing;
  }
}