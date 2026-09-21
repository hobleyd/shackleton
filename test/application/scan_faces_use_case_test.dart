import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/application/use_cases/scan_faces_use_case.dart';
import 'package:shackleton/domain/repositories/i_faces_repository.dart';
import 'package:shackleton/domain/services/i_face_recognition_service.dart';
import 'package:shackleton/models/file_of_interest.dart';

class MockFaceRecognitionService extends Mock implements IFaceRecognitionService {}

class MockFacesRepository extends Mock implements IFacesRepository {}

void main() {
  late MockFaceRecognitionService mockFaceService;
  late MockFacesRepository mockFacesRepo;
  late ScanFacesUseCase useCase;
  late Directory tempDir;

  setUpAll(() {
    registerFallbackValue(<FaceDetection>[]);
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('scan_faces_test_');
    mockFaceService = MockFaceRecognitionService();
    mockFacesRepo = MockFacesRepository();
    useCase = ScanFacesUseCase(faceService: mockFaceService, facesRepo: mockFacesRepo);
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest imageFile(String name) =>
      FileOfInterest(entity: File('${tempDir.path}/$name')..writeAsBytesSync([]));

  group('ScanFacesUseCase', () {
    test('does nothing when there are no image files', () async {
      final textFile = FileOfInterest(entity: File('${tempDir.path}/notes.txt')..writeAsBytesSync([]));

      await useCase.execute([textFile]);

      verifyNever(() => mockFacesRepo.hasBeenScanned(any()));
      verifyNever(() => mockFaceService.detectFaces(any()));
    });

    test('skips files that have already been scanned', () async {
      final file = imageFile('photo.jpg');
      when(() => mockFacesRepo.hasBeenScanned(file.path)).thenAnswer((_) async => true);

      await useCase.execute([file]);

      verify(() => mockFacesRepo.hasBeenScanned(file.path)).called(1);
      verifyNever(() => mockFaceService.detectFaces(any()));
      verifyNever(() => mockFacesRepo.storeFaces(any(), any()));
    });

    test('detects, stores, and marks a new image as scanned', () async {
      final file = imageFile('photo.jpg');
      final detections = [
        FaceDetection(
          bboxX: 0,
          bboxY: 0,
          bboxW: 1,
          bboxH: 1,
          confidence: 0.9,
          landmarks: const [],
          embedding: Float32List(0),
        ),
      ];
      when(() => mockFacesRepo.hasBeenScanned(file.path)).thenAnswer((_) async => false);
      when(() => mockFaceService.detectFaces(file.path)).thenAnswer((_) async => detections);
      when(() => mockFacesRepo.storeFaces(file.path, detections)).thenAnswer((_) async {});
      when(() => mockFacesRepo.markScanned(file.path)).thenAnswer((_) async {});

      await useCase.execute([file]);

      verify(() => mockFacesRepo.storeFaces(file.path, detections)).called(1);
      verify(() => mockFacesRepo.markScanned(file.path)).called(1);
    });

    test('still marks a file as scanned when face detection throws', () async {
      final file = imageFile('corrupt.jpg');
      when(() => mockFacesRepo.hasBeenScanned(file.path)).thenAnswer((_) async => false);
      when(() => mockFaceService.detectFaces(file.path)).thenThrow(Exception('decode failed'));
      when(() => mockFacesRepo.markScanned(file.path)).thenAnswer((_) async {});

      await useCase.execute([file]);

      verify(() => mockFacesRepo.markScanned(file.path)).called(1);
      verifyNever(() => mockFacesRepo.storeFaces(any(), any()));
    });

    test('skips non-image files but still processes images in the same list', () async {
      final textFile = FileOfInterest(entity: File('${tempDir.path}/notes.txt')..writeAsBytesSync([]));
      final image = imageFile('photo.jpg');
      when(() => mockFacesRepo.hasBeenScanned(image.path)).thenAnswer((_) async => false);
      when(() => mockFaceService.detectFaces(image.path)).thenAnswer((_) async => []);
      when(() => mockFacesRepo.storeFaces(image.path, [])).thenAnswer((_) async {});
      when(() => mockFacesRepo.markScanned(image.path)).thenAnswer((_) async {});

      await useCase.execute([textFile, image]);

      verifyNever(() => mockFacesRepo.hasBeenScanned(textFile.path));
      verify(() => mockFacesRepo.hasBeenScanned(image.path)).called(1);
    });

    test('reports progress for each image and a final completion callback', () async {
      final a = imageFile('a.jpg');
      final b = imageFile('b.jpg');
      when(() => mockFacesRepo.hasBeenScanned(any())).thenAnswer((_) async => true);

      final progressCalls = <(double, String)>[];
      await useCase.execute([a, b], onProgress: (progress, file) => progressCalls.add((progress, file)));

      expect(progressCalls, [
        (0.0, a.path),
        (0.5, b.path),
        (1.0, ''),
      ]);
    });

    test('never calls onProgress when there are no images to scan', () async {
      final textFile = FileOfInterest(entity: File('${tempDir.path}/notes.txt')..writeAsBytesSync([]));
      var called = false;

      await useCase.execute([textFile], onProgress: (_, _) => called = true);

      expect(called, isFalse);
    });
  });
}
