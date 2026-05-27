import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/misc/app_intents.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/contents/folder_contents.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';
import 'package:shackleton/providers/metadata.dart';
import 'package:shackleton/widgets/folders/folder_pane_controller.dart';

// Fake FolderContents that returns a static list without calling Directory.watch().
// This prevents the test runner from hanging on an unclosed filesystem stream.
List<FileOfInterest> _testEntities = [];

class _StaticFolderContents extends FolderContents {
  @override
  List<FileOfInterest> build(String path) => _testEntities;
}

// Fake SelectedFolderContents that skips the Future(() { register(); }) call in
// build(). That call creates a pending timer the test framework cannot clean up,
// causing the test to time out at cleanup.
class _NoTimerSelectedFolderContents extends SelectedFolderContents {
  @override
  Set<FileOfInterest> build() => {};
}

// Fake Metadata that returns empty state synchronously. The real Metadata.build()
// calls _load() unawaited which queries sqflite via an isolate; inside FakeAsync
// that isolate reply blocks the event loop and causes the test to hang.
class _StubMetadata extends Metadata {
  @override
  FileMetaData build(FileOfInterest entity) => const FileMetaData(entity: null, tags: []);
}

/// A minimal ConsumerStatefulWidget that mirrors the keyboard wiring used in
/// FolderDropZone (Shortcuts → Actions → MouseRegion → Focus → content) but
/// without the drag-and-drop machinery that is hard to initialise in tests.
class _TestFolderPane extends ConsumerStatefulWidget {
  final Directory path;
  const _TestFolderPane({required this.path});

  @override
  ConsumerState<_TestFolderPane> createState() => _TestFolderPaneState();
}

class _TestFolderPaneState extends ConsumerState<_TestFolderPane> {
  late FolderPaneController controller;
  final FocusNode focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    controller = FolderPaneController(context: context, ref: ref, path: widget.path);
  }

  @override
  Widget build(BuildContext context) {
    final entities = ref.watch(folderContentsProvider(widget.path.path));

    controller.folderEntities = List.from(entities);
    controller.visibilityCallback = (_) {};

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowDown): NavigateDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): NavigateDownIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp): NavigateUpIntent(),
        SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): NavigateUpIntent(),
      },
      child: Actions(
        actions: {
          NavigateDownIntent: CallbackAction<NavigateDownIntent>(onInvoke: (_) => controller.down()),
          NavigateUpIntent: CallbackAction<NavigateUpIntent>(onInvoke: (_) => controller.up()),
        },
        child: MouseRegion(
          onEnter: (_) => focusNode.requestFocus(),
          child: Focus(
            focusNode: focusNode,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: entities.length,
              itemBuilder: (context, index) {
                final entity = entities[index];
                return GestureDetector(
                  onTap: () => controller.selectEntity(index),
                  child: Text(entity.path, key: ValueKey(entity.path)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }
}

void main() {
  late Directory tempDir;
  late List<FileOfInterest> entities;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('folder_keyboard_test_');

    // Create 4 files; sort by name so order is deterministic.
    final files = await Future.wait([
      File('${tempDir.path}/a.txt').create(),
      File('${tempDir.path}/b.txt').create(),
      File('${tempDir.path}/c.txt').create(),
      File('${tempDir.path}/d.txt').create(),
    ]);
    files.sort((a, b) => a.path.compareTo(b.path));
    entities = files.map((f) => FileOfInterest(entity: f)).toList();
    _testEntities = entities;
  });

  tearDown(() async {
    _testEntities = [];
    await tempDir.delete(recursive: true);
  });

  ProviderContainer makeContainer(Directory path) => ProviderContainer(overrides: [
    folderContentsProvider(path.path).overrideWith(_StaticFolderContents.new),
    selectedFolderContentsProvider.overrideWith(_NoTimerSelectedFolderContents.new),
    metadataProvider.overrideWith(_StubMetadata.new),
  ]);

  Widget buildApp(ProviderContainer container, Directory path) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 400,
          child: _TestFolderPane(path: path),
        ),
      ),
    ),
  );

  group('Folder pane keyboard selection', () {
    testWidgets('ArrowDown moves selection to first item', (tester) async {
      final container = makeContainer(tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, tempDir));
      await tester.pump();

      final focusNode = tester.state<_TestFolderPaneState>(find.byType(_TestFolderPane)).focusNode;
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      final selected = container.read(selectedFolderContentsProvider);
      expect(selected, hasLength(1));
    });

    testWidgets('Shift+ArrowDown extends selection to two items', (tester) async {
      final container = makeContainer(tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, tempDir));
      await tester.pump();

      final focusNode = tester.state<_TestFolderPaneState>(find.byType(_TestFolderPane)).focusNode;
      focusNode.requestFocus();
      await tester.pump();

      // Select the first item.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Extend selection downward with Shift+ArrowDown.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final selected = container.read(selectedFolderContentsProvider);
      expect(selected, hasLength(2),
          reason: 'Shift+ArrowDown should extend selection from 1 item to 2');
    });

    testWidgets('Multiple Shift+ArrowDown presses extend selection further', (tester) async {
      final container = makeContainer(tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, tempDir));
      await tester.pump();

      final focusNode = tester.state<_TestFolderPaneState>(find.byType(_TestFolderPane)).focusNode;
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();

      // Extend selection by two more rows.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final selected = container.read(selectedFolderContentsProvider);
      expect(selected, hasLength(3),
          reason: 'Two Shift+ArrowDown presses should produce a 3-item selection');
    });

    testWidgets('Click on item then Shift+ArrowDown selects two items', (tester) async {
      final container = makeContainer(tempDir);
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, tempDir));
      await tester.pump();

      final focusNode = tester.state<_TestFolderPaneState>(find.byType(_TestFolderPane)).focusNode;
      focusNode.requestFocus();
      await tester.pump();

      // Click the first file to select it.
      await tester.tap(find.text(entities[0].path));
      await tester.pump();

      // Extend selection downward.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final selected = container.read(selectedFolderContentsProvider);
      expect(selected, hasLength(2),
          reason: 'Shift+ArrowDown after a mouse click should extend selection to 2 items');
    });
  });
}
