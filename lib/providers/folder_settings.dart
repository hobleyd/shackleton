import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/folder_ui_settings.dart';
import '../repositories/folder_settings_repository.dart';

part 'folder_settings.g.dart';

@riverpod
class FolderSettings extends _$FolderSettings {
  late FolderSettingsRepository repository;

  @override
  FolderUISettings build(FileSystemEntity entity) {
    repository = FolderSettingsRepository(ref.read(appDbProvider));

    if (!repository.folderSettings.containsKey(entity.path)) {
      repository.update(FolderUISettings(entity: entity, width: 200, isDropZone: false));
    }
    return repository.folderSettings[entity.path]!;
  }

  void changeWidth(double delta) {
    state = state.copyWith(width: state.width + delta);

    saveFolderSettings();
  }

  void saveFolderSettings() {
    repository.update(state);
  }

  void setDropZone(bool isDropZone) {
    if (state.isDropZone != isDropZone) {
      state = state.copyWith(isDropZone: isDropZone);
    }
  }
}
