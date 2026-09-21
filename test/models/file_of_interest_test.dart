import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/models/file_of_interest.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('file_of_interest_test_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  FileOfInterest fileEntity(String name, {List<int> bytes = const []}) {
    final file = File('${tempDir.path}/$name')..writeAsBytesSync(bytes);
    return FileOfInterest(entity: file);
  }

  group('basic getters', () {
    test('name returns the basename', () {
      expect(fileEntity('photo.jpg').name, 'photo.jpg');
    });

    test('path returns the underlying entity path', () {
      final entity = fileEntity('photo.jpg');
      expect(entity.path, '${tempDir.path}/photo.jpg');
    });

    test('extension is lowercase', () {
      expect(fileEntity('photo.JPG').extension, 'jpg');
    });

    test('isHidden is true for dotfiles', () {
      expect(fileEntity('.hidden').isHidden, isTrue);
    });

    test('isHidden is false for regular files', () {
      expect(fileEntity('visible.txt').isHidden, isFalse);
    });

    test('exists reflects the filesystem', () {
      final missing = FileOfInterest(entity: File('${tempDir.path}/missing.jpg'));
      expect(fileEntity('photo.jpg').exists, isTrue);
      expect(missing.exists, isFalse);
    });

    test('isDirectory is true for a directory entity', () {
      expect(FileOfInterest(entity: tempDir).isDirectory, isTrue);
    });

    test('isDirectory is false for a file entity', () {
      expect(fileEntity('photo.jpg').isDirectory, isFalse);
    });

    test('isFile is true for a file entity', () {
      expect(fileEntity('photo.jpg').isFile, isTrue);
    });
  });

  group('extension-based classification', () {
    test('isImage is true for known image extensions', () {
      expect(fileEntity('photo.png').isImage, isTrue);
      expect(fileEntity('photo.jpg').isImage, isTrue);
    });

    test('isImage is false for non-image extensions', () {
      expect(fileEntity('video.mp4').isImage, isFalse);
    });

    test('isVideo is true for known video extensions', () {
      expect(fileEntity('clip.mp4').isVideo, isTrue);
      expect(fileEntity('clip.mov').isVideo, isTrue);
    });

    test('isMetadataSupported is true for images, videos, and documents', () {
      expect(fileEntity('photo.jpg').isMetadataSupported, isTrue);
      expect(fileEntity('clip.mp4').isMetadataSupported, isTrue);
      expect(fileEntity('doc.pdf').isMetadataSupported, isTrue);
    });

    test('isMetadataSupported is false for an unrelated extension', () {
      expect(fileEntity('archive.zip').isMetadataSupported, isFalse);
    });

    test('isLocationSupported is true for images and videos only', () {
      expect(fileEntity('photo.jpg').isLocationSupported, isTrue);
      expect(fileEntity('clip.mp4').isLocationSupported, isTrue);
      expect(fileEntity('doc.pdf').isLocationSupported, isFalse);
    });

    test('canPreview is true for images, videos, and documents', () {
      expect(fileEntity('photo.jpg').canPreview, isTrue);
      expect(fileEntity('clip.mp4').canPreview, isTrue);
      expect(fileEntity('doc.md').canPreview, isTrue);
    });

    test('canPreview is false for an unrelated extension', () {
      expect(fileEntity('archive.zip').canPreview, isFalse);
    });

    test('shouldImport is true for images and videos', () {
      expect(fileEntity('photo.jpg').shouldImport, isTrue);
      expect(fileEntity('clip.mp4').shouldImport, isTrue);
    });

    test('shouldImport is false for a document', () {
      expect(fileEntity('doc.pdf').shouldImport, isFalse);
    });
  });

  group('equality and comparison', () {
    test('two entities with the same path are equal', () {
      expect(fileEntity('a.jpg'), FileOfInterest(entity: File('${tempDir.path}/a.jpg')));
    });

    test('two entities with different paths are not equal', () {
      expect(fileEntity('a.jpg') == fileEntity('b.jpg'), isFalse);
    });

    test('compareTo orders by path', () {
      final a = fileEntity('a.jpg');
      final b = fileEntity('b.jpg');
      expect(a.compareTo(b), lessThan(0));
      expect(b.compareTo(a), greaterThan(0));
    });
  });

  group('isValidMoveLocation', () {
    test('rejects a destination whose parent directory does not exist', () {
      final entity = fileEntity('a.jpg');
      expect(entity.isValidMoveLocation('${tempDir.path}/missing-dir/a.jpg'), isFalse);
    });

    test('rejects moving a file to its own current location', () {
      final entity = fileEntity('a.jpg');
      expect(entity.isValidMoveLocation(entity.path), isFalse);
    });

    test('rejects moving a directory inside itself', () {
      final entity = FileOfInterest(entity: tempDir);
      final nestedDestination = '${tempDir.path}/nested';
      expect(entity.isValidMoveLocation(nestedDestination), isFalse);
    });

    test('accepts a valid destination in an existing directory', () {
      final destinationDir = Directory('${tempDir.path}/dest')..createSync();
      final entity = fileEntity('a.jpg');
      expect(entity.isValidMoveLocation('${destinationDir.path}/a.jpg'), isTrue);
    });
  });

  group('moveFile', () {
    test('moves the file to the destination path', () {
      final entity = fileEntity('a.jpg', bytes: [1, 2, 3]);
      final destination = '${tempDir.path}/dest/a.jpg';

      final moved = entity.moveFile(destination);

      expect(moved.existsSync(), isTrue);
      expect(moved.readAsBytesSync(), [1, 2, 3]);
      expect(File(entity.path).existsSync(), isFalse);
    });

    test('creates missing parent directories', () {
      final entity = fileEntity('a.jpg');
      final destination = '${tempDir.path}/a/b/c/a.jpg';

      entity.moveFile(destination);

      expect(File(destination).existsSync(), isTrue);
    });
  });

  group('moveDirectory', () {
    test('moves a directory and its contents to the destination path', () async {
      final sourceDir = Directory('${tempDir.path}/source')..createSync();
      File('${sourceDir.path}/child.txt').writeAsStringSync('hello');
      final entity = FileOfInterest(entity: sourceDir);
      final destination = '${tempDir.path}/dest';

      await entity.moveDirectory(destination);

      expect(Directory(destination).existsSync(), isTrue);
      expect(File('$destination/child.txt').existsSync(), isTrue);
      expect(sourceDir.existsSync(), isFalse);
    });
  });

  group('copyDirectory', () {
    test('recursively copies nested files and directories', () {
      final sourceDir = Directory('${tempDir.path}/source')..createSync();
      Directory('${sourceDir.path}/nested').createSync();
      File('${sourceDir.path}/top.txt').writeAsStringSync('top');
      File('${sourceDir.path}/nested/inner.txt').writeAsStringSync('inner');
      final destinationDir = Directory('${tempDir.path}/dest')..createSync();
      final entity = FileOfInterest(entity: sourceDir);

      entity.copyDirectory(sourceDir, destinationDir);

      expect(File('${destinationDir.path}/top.txt').existsSync(), isTrue);
      expect(File('${destinationDir.path}/nested/inner.txt').existsSync(), isTrue);
      // The original is left untouched -- copy, not move.
      expect(sourceDir.existsSync(), isTrue);
    });
  });

  group('rename', () {
    test('renames the entity on disk', () {
      final entity = fileEntity('a.jpg', bytes: [9]);

      final renamed = entity.rename('b.jpg');

      expect(renamed.name, 'b.jpg');
      expect(File(renamed.path).readAsBytesSync(), [9]);
      expect(File(entity.path).existsSync(), isFalse);
    });

    test('returns the same instance when the name is unchanged', () {
      final entity = fileEntity('a.jpg');

      final result = entity.rename('a.jpg');

      expect(identical(result, entity), isTrue);
      expect(File(entity.path).existsSync(), isTrue);
    });
  });

  group('getFileSha256 / different', () {
    test('two files with identical content hash the same', () async {
      final a = fileEntity('a.jpg', bytes: [1, 2, 3, 4]);
      final b = fileEntity('b.jpg', bytes: [1, 2, 3, 4]);

      expect(await a.getFileSha256(), await b.getFileSha256());
    });

    test('two files with different content hash differently', () async {
      final a = fileEntity('a.jpg', bytes: [1, 2, 3, 4]);
      final b = fileEntity('b.jpg', bytes: [5, 6, 7, 8]);

      expect(await a.getFileSha256(), isNot(await b.getFileSha256()));
    });

    test('different() is false for files with identical content', () async {
      final a = fileEntity('a.jpg', bytes: [1, 2, 3]);
      final b = fileEntity('b.jpg', bytes: [1, 2, 3]);

      expect(await a.different(b), isFalse);
    });

    test('different() is true for files with different content', () async {
      final a = fileEntity('a.jpg', bytes: [1, 2, 3]);
      final b = fileEntity('b.jpg', bytes: [4, 5, 6]);

      expect(await a.different(b), isTrue);
    });
  });
}
