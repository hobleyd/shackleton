
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/app_settings.dart';
import '../repositories/app_settings_repository.dart';

part 'settings.g.dart';

@riverpod
class Settings extends _$Settings {
    late AppSettingsRepository repository;

    @override
    AppSettings build() {
        repository = AppSettingsRepository(ref.read(appDbProvider));

        return repository.appSettings;
    }

    get appSettings => repository.appSettings;
}
