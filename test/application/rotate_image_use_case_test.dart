import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shackleton/application/use_cases/rotate_image_use_case.dart';
import 'package:shackleton/models/file_of_interest.dart';

void main() {
  late Directory tempDir;
  late RotateImageUseCase useCase;

  img.Image testImage() {
    final image = img.Image(width: 4, height: 2);
    img.fill(image, color: img.ColorRgb8(255, 0, 0));
    return image;
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rotate_image_test_');
    useCase = RotateImageUseCase();
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('RotateImageUseCase', () {
    test('rotates a PNG by 90 degrees and swaps width/height', () async {
      final file = File('${tempDir.path}/photo.png')..writeAsBytesSync(img.encodePng(testImage()));
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 90);

      expect(result, isNotNull);
      final decoded = img.decodePng(result!);
      expect(decoded!.width, 2);
      expect(decoded.height, 4);
    });

    test('overwrites the source file with the rotated bytes', () async {
      final file = File('${tempDir.path}/photo.png')..writeAsBytesSync(img.encodePng(testImage()));
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 90);

      expect(file.readAsBytesSync(), result);
    });

    test('rotating by 180 degrees preserves the original dimensions', () async {
      final file = File('${tempDir.path}/photo.png')..writeAsBytesSync(img.encodePng(testImage()));
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 180);

      final decoded = img.decodePng(result!);
      expect(decoded!.width, 4);
      expect(decoded.height, 2);
    });

    test('encodes back to JPEG for a .jpg source', () async {
      final file = File('${tempDir.path}/photo.jpg')..writeAsBytesSync(img.encodeJpg(testImage()));
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 90);

      // JPEG files start with the SOI marker 0xFFD8.
      expect(result!.sublist(0, 2), [0xFF, 0xD8]);
      final decoded = img.decodeJpg(result);
      expect(decoded!.width, 2);
      expect(decoded.height, 4);
    });

    test('returns the original bytes unchanged for an unsupported extension', () async {
      final originalBytes = img.encodePng(testImage());
      final file = File('${tempDir.path}/photo.bmp')..writeAsBytesSync(originalBytes);
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 90);

      expect(result, originalBytes);
    });

    test('returns null when the file cannot be decoded as an image', () async {
      final file = File('${tempDir.path}/photo.png')
        ..writeAsStringSync('not a real image file, just plain text content for testing purposes');
      final entity = FileOfInterest(entity: file);

      final result = await useCase.execute(entity, 90);

      expect(result, isNull);
    });
  });
}
