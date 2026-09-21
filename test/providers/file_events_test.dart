import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/interfaces/file_events_callback.dart';
import 'package:shackleton/models/file_of_interest.dart';
import 'package:shackleton/providers/file_events.dart';

import '../helpers/test_database.dart';

class RecordingCallback implements FileEventsCallback {
  final List<FileOfInterest> removed = [];

  @override
  void remove(FileOfInterest entity) => removed.add(entity);
}

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('file_events_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileEvents notifier() => container.read(fileEventsProvider.notifier);

  group('register', () {
    test('adds a callback', () {
      final callback = RecordingCallback();

      notifier().register(callback);

      expect(container.read(fileEventsProvider), contains(callback));
    });

    test('does not add the same callback twice', () {
      final callback = RecordingCallback();

      notifier().register(callback);
      notifier().register(callback);

      expect(container.read(fileEventsProvider), hasLength(1));
    });
  });

  group('delete', () {
    // deleteEntity: true on a file that exists would call DeleteFilesUseCase,
    // which moves it into the real ~/.Trash on macOS/Linux (no override
    // point) -- so these tests only ever pass deleteEntity: true for entities
    // that do not exist on disk, and use deleteEntity: false to observe the
    // callback/notification behaviour on real files without touching them.
    test('notifies every registered callback, deleteEntity: false leaves the file alone', () {
      final callback = RecordingCallback();
      notifier().register(callback);
      final file = File('${tempDir.path}/a.jpg')..writeAsBytesSync([]);
      final entity = FileOfInterest(entity: file);

      notifier().delete(entity, deleteEntity: false);

      expect(callback.removed, [entity]);
      expect(file.existsSync(), isTrue);
    });

    test('deleteEntity: true is a no-op on the filesystem when the entity does not exist', () {
      final callback = RecordingCallback();
      notifier().register(callback);
      final entity = FileOfInterest(entity: File('${tempDir.path}/missing.jpg'));

      // Should not throw and should not attempt any real deletion.
      notifier().delete(entity, deleteEntity: true);

      expect(callback.removed, [entity]);
    });

    test('recurses into a directory, notifying for every child then the directory itself', () {
      final callback = RecordingCallback();
      notifier().register(callback);
      final subDir = Directory('${tempDir.path}/sub')..createSync();
      final child = File('${subDir.path}/a.jpg')..writeAsBytesSync([]);
      final dirEntity = FileOfInterest(entity: subDir);

      notifier().delete(dirEntity, deleteEntity: false);

      expect(callback.removed.map((e) => e.path), [child.path, subDir.path]);
    });

    test('notifies all registered callbacks, not just the first', () {
      final a = RecordingCallback();
      final b = RecordingCallback();
      notifier().register(a);
      notifier().register(b);
      final entity = FileOfInterest(entity: File('${tempDir.path}/x.jpg'));

      notifier().delete(entity, deleteEntity: false);

      expect(a.removed, [entity]);
      expect(b.removed, [entity]);
    });
  });

  group('deleteAll', () {
    test('calls delete for every entity in the set', () {
      final callback = RecordingCallback();
      notifier().register(callback);
      final a = FileOfInterest(entity: File('${tempDir.path}/a.jpg'));
      final b = FileOfInterest(entity: File('${tempDir.path}/b.jpg'));

      // Neither exists on disk, so deleteEntity: true is safe here too.
      notifier().deleteAll({a, b});

      expect(callback.removed, containsAll([a, b]));
    });
  });
}
