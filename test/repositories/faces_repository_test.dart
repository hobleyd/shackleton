import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/domain/services/i_face_recognition_service.dart';
import 'package:shackleton/models/face_identity.dart';
import 'package:shackleton/providers/face_recognition_service_provider.dart';
import 'package:shackleton/repositories/faces_repository.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';

import '../helpers/test_database.dart';

class MockFaceRecognitionService extends Mock implements IFaceRecognitionService {}

void main() {
  late ProviderContainer container;
  late Directory tempDir;
  late MockFaceRecognitionService mockFaceService;

  Float32List embedding(List<double> values) => Float32List.fromList(values);

  FaceDetection detection({double confidence = 0.9, List<double>? embeddingValues}) => FaceDetection(
        bboxX: 0,
        bboxY: 0,
        bboxW: 1,
        bboxH: 1,
        confidence: confidence,
        landmarks: const [],
        embedding: embedding(embeddingValues ?? [1, 0, 0]),
      );

  setUpAll(() {
    registerFallbackValue(Float32List(0));
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('faces_repository_test_');
    mockFaceService = MockFaceRecognitionService();
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
      faceRecognitionServiceProvider.overrideWithValue(mockFaceService),
    ]);
    await container.read(appDatabaseProvider.future);
    await container.read(facesRepositoryProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FacesRepository repo() => container.read(facesRepositoryProvider.notifier);

  group('Identities', () {
    test('getIdentityByName returns null when no identity exists', () async {
      expect(await repo().getIdentityByName('Alice'), isNull);
    });

    test('upsertIdentity inserts a new identity and it can be read back', () async {
      final saved = await repo().upsertIdentity('Alice', embedding([1, 2, 3]));

      expect(saved.name, 'Alice');
      expect(saved.embedding, embedding([1, 2, 3]));

      final found = await repo().getIdentityByName('Alice');
      expect(found, isNotNull);
      expect(found!.embedding, embedding([1, 2, 3]));
    });

    test('upsertIdentity replaces the embedding for an existing name', () async {
      await repo().upsertIdentity('Alice', embedding([1, 2, 3]));
      await repo().upsertIdentity('Alice', embedding([4, 5, 6]));

      final identities = await repo().getAllIdentities();
      expect(identities, hasLength(1));
      expect(identities.first.embedding, embedding([4, 5, 6]));
    });

    test('getAllIdentities returns identities ordered by name', () async {
      await repo().upsertIdentity('Charlie', embedding([1]));
      await repo().upsertIdentity('Alice', embedding([2]));
      await repo().upsertIdentity('Bob', embedding([3]));

      final identities = await repo().getAllIdentities();

      expect(identities.map((i) => i.name), ['Alice', 'Bob', 'Charlie']);
    });
  });

  group('Face storage and scan status', () {
    test('storeFaces creates the file row and stores each detection', () async {
      await repo().storeFaces('/a.jpg', [detection(), detection(confidence: 0.5)]);

      final db = container.read(appDatabaseProvider.notifier);
      final files = await db.query('files', where: 'path = ?', whereArgs: ['/a.jpg']);
      expect(files, hasLength(1));

      final faces = await db.query('file_faces', where: 'file_id = ?', whereArgs: [files.first['id']]);
      expect(faces, hasLength(2));
    });

    test('storeFaces replaces previous detections for the same file on re-scan', () async {
      await repo().storeFaces('/a.jpg', [detection(), detection()]);
      await repo().storeFaces('/a.jpg', [detection()]);

      final db = container.read(appDatabaseProvider.notifier);
      final files = await db.query('files', where: 'path = ?', whereArgs: ['/a.jpg']);
      final faces = await db.query('file_faces', where: 'file_id = ?', whereArgs: [files.first['id']]);
      expect(faces, hasLength(1));
    });

    test('hasBeenScanned is false until markScanned is called', () async {
      expect(await repo().hasBeenScanned('/a.jpg'), isFalse);

      await repo().markScanned('/a.jpg');

      expect(await repo().hasBeenScanned('/a.jpg'), isTrue);
    });

    test('markScanned is idempotent for the same path', () async {
      await repo().markScanned('/a.jpg');
      await repo().markScanned('/a.jpg');

      final db = container.read(appDatabaseProvider.notifier);
      final files = await db.query('files', where: 'path = ?', whereArgs: ['/a.jpg']);
      expect(files, hasLength(1));
      final status = await db.query('file_face_scan_status', where: 'file_id = ?', whereArgs: [files.first['id']]);
      expect(status, hasLength(1));
    });

    test('getScannedPathsFromSet returns only the scanned subset', () async {
      await repo().markScanned('/a.jpg');

      final result = await repo().getScannedPathsFromSet(['/a.jpg', '/b.jpg']);

      expect(result, {'/a.jpg'});
    });

    test('getScannedPathsFromSet returns empty for an empty input', () async {
      expect(await repo().getScannedPathsFromSet([]), isEmpty);
    });
  });

  group('findFilesMatchingIdentity', () {
    test('returns files whose stored embedding is above the threshold', () async {
      final file = File('${tempDir.path}/match.jpg')..writeAsBytesSync([]);
      await repo().storeFaces(file.path, [detection(embeddingValues: [1, 0, 0])]);
      when(() => mockFaceService.cosineSimilarity(any(), any())).thenReturn(0.9);
      final identity = FaceIdentity(name: 'Alice', embedding: embedding([1, 0, 0]));

      final result = await repo().findFilesMatchingIdentity(identity, 0.8);

      expect(result, hasLength(1));
      expect(result.first.file.path, file.path);
      expect(result.first.similarity, 0.9);
    });

    test('excludes files whose similarity is below the threshold', () async {
      final file = File('${tempDir.path}/nomatch.jpg')..writeAsBytesSync([]);
      await repo().storeFaces(file.path, [detection()]);
      when(() => mockFaceService.cosineSimilarity(any(), any())).thenReturn(0.2);
      final identity = FaceIdentity(name: 'Alice', embedding: embedding([1, 0, 0]));

      final result = await repo().findFilesMatchingIdentity(identity, 0.8);

      expect(result, isEmpty);
    });

    test('excludes files that no longer exist on disk', () async {
      // File is stored but never created on disk.
      await repo().storeFaces('${tempDir.path}/ghost.jpg', [detection()]);
      when(() => mockFaceService.cosineSimilarity(any(), any())).thenReturn(0.99);
      final identity = FaceIdentity(name: 'Alice', embedding: embedding([1, 0, 0]));

      final result = await repo().findFilesMatchingIdentity(identity, 0.8);

      expect(result, isEmpty);
    });

    test('excludes files already tagged with excludeTagName', () async {
      final file = File('${tempDir.path}/tagged.jpg')..writeAsBytesSync([]);
      await repo().storeFaces(file.path, [detection()]);
      when(() => mockFaceService.cosineSimilarity(any(), any())).thenReturn(0.9);

      final tagsRepo = container.read(fileTagsRepositoryProvider.notifier);
      await tagsRepo.addTagToFile(file.path, 'Alice');

      final identity = FaceIdentity(name: 'Alice', embedding: embedding([1, 0, 0]));
      final result = await repo().findFilesMatchingIdentity(identity, 0.8, excludeTagName: 'Alice');

      expect(result, isEmpty);
    });

    test('sorts matches by descending similarity', () async {
      final low = File('${tempDir.path}/low.jpg')..writeAsBytesSync([]);
      final high = File('${tempDir.path}/high.jpg')..writeAsBytesSync([]);
      await repo().storeFaces(low.path, [detection(embeddingValues: [0, 1, 0])]);
      await repo().storeFaces(high.path, [detection(embeddingValues: [1, 0, 0])]);
      // Similarity keyed off the stored face embedding's first component so
      // the two files resolve to genuinely different scores.
      when(() => mockFaceService.cosineSimilarity(any(), any())).thenAnswer((invocation) {
        final faceEmbedding = invocation.positionalArguments[1] as Float32List;
        return faceEmbedding.first > 0 ? 0.95 : 0.5;
      });
      final identity = FaceIdentity(name: 'Alice', embedding: embedding([1, 0, 0]));

      final result = await repo().findFilesMatchingIdentity(identity, 0.4);

      expect(result, hasLength(2));
      expect(result[0].file.path, high.path);
      expect(result[1].file.path, low.path);
      expect(result[0].similarity, greaterThan(result[1].similarity));
    });
  });
}
