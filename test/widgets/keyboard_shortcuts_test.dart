import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shackleton/misc/app_intents.dart';

/// Verifies that the Shortcuts → Actions → Focus widget structure that the
/// app uses for keyboard navigation actually fires intents correctly.
///
/// These tests are deliberately kept free of app-specific providers so they
/// isolate the Flutter mechanism from the app logic.
void main() {
  group('Shortcuts / Actions / Focus wiring', () {
    testWidgets('ArrowDown fires NavigateDownIntent on focused widget', (tester) async {
      bool fired = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        home: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown): NavigateDownIntent(),
          },
          child: Actions(
            actions: {
              NavigateDownIntent: CallbackAction<NavigateDownIntent>(
                onInvoke: (_) { fired = true; return null; },
              ),
            },
            child: Focus(
              focusNode: focusNode,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue, reason: 'FocusNode should have focus after requestFocus()');

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(fired, isTrue, reason: 'NavigateDownIntent should fire when ArrowDown pressed on focused widget');
    });

    testWidgets('Shift+ArrowDown fires NavigateDownIntent and isShiftPressed is true inside action', (tester) async {
      bool fired = false;
      bool shiftSeen = false;
      final focusNode = FocusNode();

      await tester.pumpWidget(MaterialApp(
        home: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): NavigateDownIntent(),
          },
          child: Actions(
            actions: {
              NavigateDownIntent: CallbackAction<NavigateDownIntent>(
                onInvoke: (_) {
                  fired = true;
                  shiftSeen = HardwareKeyboard.instance.isShiftPressed;
                  return null;
                },
              ),
            },
            child: Focus(
              focusNode: focusNode,
              child: const SizedBox(width: 200, height: 200),
            ),
          ),
        ),
      ));

      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(fired, isTrue, reason: 'NavigateDownIntent should fire on Shift+ArrowDown');
      expect(shiftSeen, isTrue, reason: 'HardwareKeyboard.isShiftPressed must be true inside the action');
    });

    testWidgets('Shortcuts do not fire when FocusNode does not have focus', (tester) async {
      bool fired = false;
      final focusNode = FocusNode();
      final otherFocus = FocusNode();

      await tester.pumpWidget(MaterialApp(
        home: Column(children: [
          Shortcuts(
            shortcuts: const {
              SingleActivator(LogicalKeyboardKey.arrowDown): NavigateDownIntent(),
            },
            child: Actions(
              actions: {
                NavigateDownIntent: CallbackAction<NavigateDownIntent>(
                  onInvoke: (_) { fired = true; return null; },
                ),
              },
              child: Focus(
                focusNode: focusNode,
                child: const SizedBox(width: 200, height: 100),
              ),
            ),
          ),
          // This widget takes focus instead.
          Focus(
            focusNode: otherFocus,
            child: const SizedBox(width: 200, height: 100),
          ),
        ]),
      ));

      // Give focus to the OTHER widget so focusNode does not have it.
      otherFocus.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      expect(fired, isFalse, reason: 'Shortcut must not fire when its FocusNode is not focused');
    });
  });
}
