import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_app_settings_repository.dart';
import '../misc/utils.dart';
import '../models/app_settings.dart';
import '../providers/shackleton_theme.dart';

part 'app_settings_repository.g.dart';

@riverpod
class AppSettingsRepository extends _$AppSettingsRepository implements IAppSettingsRepository {
  static const String tableName = 'app_settings';

  late final AppDatabase _db;
  late final ShackletonTheme _theme;

  @override
  Future<AppSettings> build() {
    ref.keepAlive();
    _db = ref.read(appDatabaseProvider.notifier);
    _theme = ref.read(shackletonThemeProvider.notifier);
    return getSettings();
  }

  @override
  Future<AppSettings> getSettings() async {
    late AppSettings appSettings;
    List<Map<String, dynamic>> rows = await _db.query(tableName, where: 'id = ?', whereArgs: [ 0 ]);
    if (rows.isNotEmpty) {
      appSettings = AppSettings.fromJson(rows.first);
    } else {
      appSettings = AppSettings(id: 0, libraryPath: join(getHomeFolder(), 'Pictures'), fontSize: 12);
    }

    _theme.setFontSize(appSettings.fontSize.toDouble());
    return appSettings;
  }

  @override
  Future<int> updateSettings(AppSettings appSettings) async {
    _theme.setFontSize(appSettings.fontSize.toDouble());

    int rowId = await _db.insert(tableName, appSettings.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
    final newState = await AsyncValue.guard(() => getSettings());
    if (ref.mounted) state = newState;
    return rowId;
  }
}