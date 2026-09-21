import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/domain/services/i_face_recognition_service.dart';
import 'package:shackleton/providers/face_cache_warmer.dart';
import 'package:shackleton/providers/face_recognition_service_provider.dart';
import 'package:shackleton/repositories/faces_repository.dart';

import '../helpers/test_database.dart';

class MockFaceRecognitionService extends Mock implements IFaceRecognitionService {}

void main() {
  late ProviderContainer container;
  late Directory tempDir;
  late MockFaceRecognitionService mockFaceService;

  setUpAll(() {
    registerFallbackValue(<FaceDetection>[]);
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Same guardrail as metadata_cache_warmer_test.dart: appSettingsRepositoryProvider
    // otherwise defaults libraryPath to the real ~/Pictures.
    tempDir = await Directory.systemTemp.createTemp('face_cache_warmer_test_');
    mockFaceService = MockFaceRecognitionService();
    when(() => mockFaceService.modelsAvailable).thenAnswer((_) async => true);
    container = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWith(InMemoryAppDatabase.new),
      faceRecognitionServiceProvider.overrideWithValue(mockFaceService),
    ]);
    final db = container.read(appDatabaseProvider.notifier);
    await container.read(appDatabaseProvider.future);
    await db.insert('app_settings', {'id': 0, 'libraryPath': tempDir.path, 'fontSize': 12});
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  Future<void> settle() async {
    final sub = container.listen(faceCacheWarmerProvider, (_, _) {});
    await Future.delayed(const Duration(milliseconds: 300));
    sub.close();
  }

  group('FaceCacheWarmer', () {
    test('scans unscanned image files under the library path', () async {
      final photo = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      when(() => mockFaceService.detectFaces(photo.path)).thenAnswer((_) async => []);

      await settle();

      final facesRepo = container.read(facesRepositoryProvider.notifier);
      expect(await facesRepo.hasBeenScanned(photo.path), isTrue);
    });

    test('does not re-scan a file already marked scanned', () async {
      final photo = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      final facesRepo = container.read(facesRepositoryProvider.notifier);
      await facesRepo.markScanned(photo.path);

      await settle();

      verifyNever(() => mockFaceService.detectFaces(any()));
    });

    test('ignores non-image files', () async {
      File('${tempDir.path}/notes.txt').writeAsBytesSync([]);

      await settle();

      verifyNever(() => mockFaceService.detectFaces(any()));
    });

    test('does nothing when models are not available', () async {
      when(() => mockFaceService.modelsAvailable).thenAnswer((_) async => false);
      File('${tempDir.path}/photo.jpg').writeAsBytesSync([]);

      await settle();

      verifyNever(() => mockFaceService.detectFaces(any()));
    });

    test('marks a file scanned even when detection throws, so it is not retried', () async {
      final photo = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      when(() => mockFaceService.detectFaces(photo.path)).thenThrow(Exception('decode failed'));

      await settle();

      final facesRepo = container.read(facesRepositoryProvider.notifier);
      expect(await facesRepo.hasBeenScanned(photo.path), isTrue);
    });

    test('state returns to not-visible once the queue drains', () async {
      final photo = File('${tempDir.path}/photo.jpg')..writeAsBytesSync([]);
      when(() => mockFaceService.detectFaces(photo.path)).thenAnswer((_) async => []);

      await settle();

      expect(container.read(faceCacheWarmerProvider).isVisible, isFalse);
    });
  });
}
