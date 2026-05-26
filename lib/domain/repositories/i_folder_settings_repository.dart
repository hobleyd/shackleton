import '../../models/folder_ui_settings.dart';

abstract class IFolderSettingsRepository {
  Future<FolderUISettings> getSettings(String path);
  Future<void> updateSettings(FolderUISettings settings);
  void updateShowDetailedView(bool show);
  void updateShowHiddenFiles(bool show);
}
