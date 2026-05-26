import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/database/app_database.dart';
import 'package:shackleton/models/app_settings.dart';
import 'package:shackleton/repositories/app_settings_repository.dart';

import '../helpers/test_database.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    container = createTestContainer();
    await container.read(appDatabaseProvider.future);
  });

  tearDown(() {
    container.dispose();
  });

  group('AppSettingsRepository', () {
    test('getSettings returns defaults when no settings have been saved', () async {
      final settings = await container.read(appSettingsRepositoryProvider.future);
      expect(settings.fontSize, 12);
      expect(settings.libraryPath, contains('Pictures'));
    });

    test('updateSettings persists the new values', () async {
      await container.read(appSettingsRepositoryProvider.future);
      final repo = container.read(appSettingsRepositoryProvider.notifier);

      const updated = AppSettings(id: 0, libraryPath: '/my/library', fontSize: 16);
      await repo.updateSettings(updated);

      final reloaded = await repo.getSettings();
      expect(reloaded.fontSize, 16);
      expect(reloaded.libraryPath, '/my/library');
    });

    test('updateSettings is idempotent — multiple saves do not create extra rows', () async {
      await container.read(appSettingsRepositoryProvider.future);
      final repo = container.read(appSettingsRepositoryProvider.notifier);

      const s1 = AppSettings(id: 0, libraryPath: '/path/one', fontSize: 14);
      const s2 = AppSettings(id: 0, libraryPath: '/path/two', fontSize: 18);
      await repo.updateSettings(s1);
      await repo.updateSettings(s2);

      final reloaded = await repo.getSettings();
      expect(reloaded.libraryPath, '/path/two');
      expect(reloaded.fontSize, 18);
    });
  });
}
