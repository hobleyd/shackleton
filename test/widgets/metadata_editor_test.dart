import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/interfaces/keyboard_callback.dart';
import 'package:shackleton/interfaces/tag_handler.dart';
import 'package:shackleton/models/file_metadata.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/contents/grid_contents.dart';
import 'package:shackleton/providers/contents/selected_folder_contents.dart';
import 'package:shackleton/providers/contents/selected_grid_entities.dart';
import 'package:shackleton/providers/metadata.dart';
import 'package:shackleton/widgets/metadata/metadata_editor.dart';

final Map<String, FileMetaData> _stubMetadataByPath = {};

class _StubMetadata extends Metadata {
  @override
  FileMetaData build(FileOfInterest entity) =>
      _stubMetadataByPath[entity.path] ?? FileMetaData(entity: entity, tags: const []);
}

// Real SelectedGridEntities.build() schedules Future(() { register(); }) to
// join FileEvents' callback list. Under testWidgets that Future becomes a
// pending fake-async timer the test framework can't clean up at teardown
// ("A Timer is still pending even after the widget tree was disposed"),
// exactly like folder_pane_keyboard_test.dart's _NoTimerSelectedFolderContents.
class _NoTimerSelectedGridEntities extends SelectedGridEntities {
  @override
  List<FileOfInterest> build() => [];
}

// gridTagsProvider's "nothing selected" branch reads gridContentsProvider,
// which reads selectedFolderContentsProvider -- both schedule the same
// register() pending timer, so both need the same no-timer treatment.
class _NoTimerSelectedFolderContents extends SelectedFolderContents {
  @override
  Set<FileOfInterest> build() => {};
}

class _NoTimerGridContents extends GridContents {
  @override
  List<FileOfInterest> build() => [];
}

class FakeKeyboardCallback implements KeyboardCallback {
  final List<String> calls = [];

  @override
  void delete() => calls.add('delete');
  @override
  void down() => calls.add('down');
  @override
  void exit() => calls.add('exit');
  @override
  void left() => calls.add('left');
  @override
  void newEntity() => calls.add('newEntity');
  @override
  void right() => calls.add('right');
  @override
  void selectAll() => calls.add('selectAll');
  @override
  void up() => calls.add('up');
}

class FakeTagHandler implements TagHandler {
  Tag? removedTag;
  String? updatedTags;

  @override
  void removeTag(Tag tag) => removedTag = tag;

  @override
  void updateTags(String tags) => updatedTags = tags;
}

void main() {
  late Directory tempDir;
  late FakeKeyboardCallback keyHandler;
  late FakeTagHandler tagHandler;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('metadata_editor_test_');
    _stubMetadataByPath.clear();
    keyHandler = FakeKeyboardCallback();
    tagHandler = FakeTagHandler();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  // None of these tests reach _filterByTag (tapping a tag's own label), the
  // only codepath that touches the DB, so no appDatabaseProvider override is
  // needed -- real sqflite_common_ffi access hangs under testWidgets (see
  // shackleton_statistics_test.dart).
  ProviderContainer makeContainer() => ProviderContainer(overrides: [
        metadataProvider.overrideWith2((entity) => _StubMetadata()),
        selectedGridEntitiesProvider.overrideWith(_NoTimerSelectedGridEntities.new),
        selectedFolderContentsProvider.overrideWith(_NoTimerSelectedFolderContents.new),
        gridContentsProvider.overrideWith(_NoTimerGridContents.new),
      ]);

  // Alternating tag rows force-unwrap Theme.of(context).textSelectionTheme
  // .selectionHandleColor, which is only non-null because ShackletonTheme
  // always sets it app-wide -- a plain MaterialApp's default theme leaves it
  // null and the widget throws, so match that real-app invariant here.
  Widget buildApp(ProviderContainer container) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            textSelectionTheme: const TextSelectionThemeData(selectionHandleColor: Color(0xf0e8e4df)),
          ),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 500,
              child: MetadataEditor(keyHandlerCallback: keyHandler, tagHandler: tagHandler),
            ),
          ),
        ),
      );

  group('MetadataEditor', () {
    testWidgets('shows the empty-state message when nothing is selected', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      expect(find.text('No tags for selected image(s)'), findsOneWidget);
    });

    testWidgets('lists the tags for the grid selection', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final entity = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      _stubMetadataByPath[entity.path] = FileMetaData(entity: entity, tags: [Tag(tag: 'nature'), Tag(tag: 'travel')]);
      container.read(selectedGridEntitiesProvider.notifier).add(entity);

      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      expect(find.text('nature'), findsOneWidget);
      expect(find.text('travel'), findsOneWidget);
    });

    testWidgets('tapping the clear icon on a tag calls TagHandler.removeTag', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      final entity = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      final tag = Tag(tag: 'nature');
      _stubMetadataByPath[entity.path] = FileMetaData(entity: entity, tags: [tag]);
      container.read(selectedGridEntitiesProvider.notifier).add(entity);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(tagHandler.removedTag, tag);
    });

    testWidgets('submitting the text field calls TagHandler.updateTags and clears the field', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();

      await tester.enterText(find.byType(TextField), 'sunset, beach');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(tagHandler.updatedTags, 'sunset, beach');
      expect(find.text('sunset, beach'), findsNothing);
    });

    testWidgets('tapping the add icon submits the current field text', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'portrait');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(tagHandler.updatedTags, 'portrait');
    });
  });
}
