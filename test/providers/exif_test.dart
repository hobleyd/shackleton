import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shackleton/domain/services/i_exif_tool_service.dart';
import 'package:shackleton/models/tag.dart';
import 'package:shackleton/providers/exif.dart';
import 'package:shackleton/providers/exif_tool_service_provider.dart';
import 'package:shackleton/providers/notify.dart';

class MockExifToolService extends Mock implements IExifToolService {}

void main() {
  late ProviderContainer container;
  late MockExifToolService mockExif;

  setUpAll(() {
    registerFallbackValue(<Tag>[]);
  });

  setUp(() {
    mockExif = MockExifToolService();
    container = ProviderContainer(overrides: [
      exifToolServiceProvider.overrideWithValue(mockExif),
    ]);
  });

  tearDown(() {
    container.dispose();
  });

  group('Exif', () {
    test('loadExifTags posts a notification and leaves state empty when exiftool is missing', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);

      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(exifProvider('/a.jpg')), isEmpty);
      expect(container.read(notifyProvider).map((n) => n.message), contains('exiftool not installed.'));
    });

    test('build loads exif data via readAllExifData when exiftool is present', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readAllExifData('/a.jpg')).thenAnswer((_) async => {
            'Orientation': (orig: '1', reset: '1'),
          });

      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(container.read(exifProvider('/a.jpg')), {'Orientation': (orig: '1', reset: '1')});
    });

    test('fixMetadata posts a notification and returns false when exiftool is missing', () async {
      when(() => mockExif.findExifTool()).thenReturn(null);
      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      // Let build()'s deferred loadExifTags settle before proceeding.
      await Future.delayed(const Duration(milliseconds: 50));

      final result = await container.read(exifProvider('/a.jpg').notifier).fixMetadata('/a.jpg');

      expect(result, isFalse);
      expect(
        container.read(notifyProvider).map((n) => n.message),
        contains('exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.'),
      );
    });

    test('fixMetadata reloads tags and returns true on success', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readAllExifData('/a.jpg')).thenAnswer((_) async => {});
      when(() => mockExif.fixMetadata('/a.jpg')).thenAnswer((_) async => true);
      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      final result = await container.read(exifProvider('/a.jpg').notifier).fixMetadata('/a.jpg');

      expect(result, isTrue);
      verify(() => mockExif.readAllExifData('/a.jpg')).called(2); // initial load + reload after fix
    });

    test('fixMetadata posts a notification and returns false when the service reports failure', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readAllExifData('/a.jpg')).thenAnswer((_) async => {});
      when(() => mockExif.fixMetadata('/a.jpg')).thenAnswer((_) async => false);
      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      final result = await container.read(exifProvider('/a.jpg').notifier).fixMetadata('/a.jpg');

      expect(result, isFalse);
      expect(container.read(notifyProvider).map((n) => n.message), contains('Resetting exif data failed for /a.jpg'));
    });

    test('acceptFix deletes the backup and reloads tags', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readAllExifData('/a.jpg')).thenAnswer((_) async => {});
      when(() => mockExif.deleteBackup('/a.jpg')).thenAnswer((_) async {});
      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      await container.read(exifProvider('/a.jpg').notifier).acceptFix('/a.jpg');

      verify(() => mockExif.deleteBackup('/a.jpg')).called(1);
      verify(() => mockExif.readAllExifData('/a.jpg')).called(2);
    });

    test('rejectFix restores the backup and reloads tags', () async {
      when(() => mockExif.findExifTool()).thenReturn('/usr/bin/exiftool');
      when(() => mockExif.readAllExifData('/a.jpg')).thenAnswer((_) async => {});
      when(() => mockExif.restoreBackup('/a.jpg')).thenAnswer((_) async {});
      final sub = container.listen(exifProvider('/a.jpg'), (_, _) {});
      addTearDown(sub.close);
      await Future.delayed(const Duration(milliseconds: 50));

      await container.read(exifProvider('/a.jpg').notifier).rejectFix('/a.jpg');

      verify(() => mockExif.restoreBackup('/a.jpg')).called(1);
      verify(() => mockExif.readAllExifData('/a.jpg')).called(2);
    });
  });
}
