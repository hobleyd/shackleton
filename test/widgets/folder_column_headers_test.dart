import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/contents/folder_contents.dart';
import 'package:shackleton/widgets/folders/folder_column_headers.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('folder_column_headers_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  // FolderContents/FolderColumnHeaders never touch the DB (sortBy etc. only
  // reorder in-memory state), so a plain ProviderContainer is enough --
  // no need for the DB-backed test container here.
  Widget buildApp(ProviderContainer container, {required bool showDetailedView}) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: FolderColumnHeaders(path: tempDir, showDetailedView: showDetailedView),
          ),
        ),
      );

  group('FolderColumnHeaders', () {
    testWidgets('shows only the Name column when showDetailedView is false', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, showDetailedView: false));
      await tester.pump();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Size'), findsNothing);
      expect(find.text('Modified'), findsNothing);
    });

    testWidgets('shows Size and Modified columns when showDetailedView is true', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(buildApp(container, showDetailedView: true));
      await tester.pump();

      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Size'), findsOneWidget);
      expect(find.text('Modified'), findsOneWidget);
    });

    testWidgets('tapping a column header sorts by that field', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container, showDetailedView: true));
      await tester.pump();

      await tester.tap(find.text('Size'));
      await tester.pump();

      final notifier = container.read(folderContentsProvider(tempDir.path).notifier);
      expect(notifier.getSortField(), EntitySortField.size);
    });

    testWidgets('tapping the active column header a second time flips the sort order', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(buildApp(container, showDetailedView: true));
      await tester.pump();
      final notifier = container.read(folderContentsProvider(tempDir.path).notifier);
      expect(notifier.getSortOrder(), EntitySortOrder.asc);

      await tester.tap(find.text('Name'));
      await tester.pump();

      expect(notifier.getSortOrder(), EntitySortOrder.desc);
    });
  });
}
