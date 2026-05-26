import '../../models/app_settings.dart';

abstract class IAppSettingsRepository {
  Future<AppSettings> getSettings();
  Future<int> updateSettings(AppSettings appSettings);
}
