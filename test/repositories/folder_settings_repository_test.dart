import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/folder_ui_settings.dart';
import 'package:shackleton/repositories/folder_settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late Directory tempDir;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('folder_settings_test_');
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() async {
    container.dispose();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('FolderSettingsRepository', () {
    test('getSettings returns defaults when nothing has been saved for the path', () async {
      final settings = await container.read(folderSettingsRepositoryProvider(tempDir.path).future);

      expect(settings.width, 200);
      expect(settings.detailedView, isFalse);
      expect(settings.showHiddenFiles, isFalse);
      expect(settings.entity.path, tempDir.path);
    });

    test('updateSettings persists and getSettings reads it back', () async {
      await container.read(folderSettingsRepositoryProvider(tempDir.path).future);
      final repo = container.read(folderSettingsRepositoryProvider(tempDir.path).notifier);

      final updated = FolderUISettings(
        entity: Directory(tempDir.path),
        width: 350,
        detailedView: true,
        showHiddenFiles: true,
      );
      await repo.updateSettings(updated);

      final reloaded = await repo.getSettings(tempDir.path);
      expect(reloaded.width, 350);
      expect(reloaded.detailedView, isTrue);
      expect(reloaded.showHiddenFiles, isTrue);
    });

    test('updateSettings replaces the previous row rather than duplicating it', () async {
      await container.read(folderSettingsRepositoryProvider(tempDir.path).future);
      final repo = container.read(folderSettingsRepositoryProvider(tempDir.path).notifier);
      final db = container.read(appDatabaseProvider.notifier);

      await repo.updateSettings(FolderUISettings(
        entity: Directory(tempDir.path), width: 100, detailedView: false, showHiddenFiles: false));
      await repo.updateSettings(FolderUISettings(
        entity: Directory(tempDir.path), width: 200, detailedView: true, showHiddenFiles: false));

      final rows = await db.query('folder_settings', where: 'entity = ?', whereArgs: [tempDir.path]);
      expect(rows, hasLength(1));
      expect(rows.first['width'], 200);
    });

    test('updateShowDetailedView flips the flag and persists it', () async {
      await container.read(folderSettingsRepositoryProvider(tempDir.path).future);
      final repo = container.read(folderSettingsRepositoryProvider(tempDir.path).notifier);

      repo.updateShowDetailedView(true);
      await Future.delayed(const Duration(milliseconds: 50));

      final reloaded = await repo.getSettings(tempDir.path);
      expect(reloaded.detailedView, isTrue);
    });

    test('updateShowHiddenFiles flips the flag and persists it', () async {
      await container.read(folderSettingsRepositoryProvider(tempDir.path).future);
      final repo = container.read(folderSettingsRepositoryProvider(tempDir.path).notifier);

      repo.updateShowHiddenFiles(true);
      await Future.delayed(const Duration(milliseconds: 50));

      final reloaded = await repo.getSettings(tempDir.path);
      expect(reloaded.showHiddenFiles, isTrue);
    });

    test('settings for different paths do not clash', () async {
      final otherDir = await tempDir.parent.createTemp('folder_settings_other_');
      addTearDown(() async {
        if (otherDir.existsSync()) await otherDir.delete(recursive: true);
      });

      await container.read(folderSettingsRepositoryProvider(tempDir.path).future);
      final repoA = container.read(folderSettingsRepositoryProvider(tempDir.path).notifier);
      await repoA.updateSettings(FolderUISettings(
        entity: Directory(tempDir.path), width: 111, detailedView: true, showHiddenFiles: false));

      final settingsB = await container.read(folderSettingsRepositoryProvider(otherDir.path).future);

      expect(settingsB.width, 200);
      expect(settingsB.detailedView, isFalse);
    });
  });
}
