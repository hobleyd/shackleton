import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../database/app_database.dart';
import '../models/folder_ui_settings.dart';
import '../repositories/folder_settings_repository.dart';

part 'folder_settings.g.dart';

@riverpod
class FolderSettings extends _$FolderSettings {
  late FolderSettingsRepository _repository;

  @override
  FolderUISettings build(FileSystemEntity entity) {
    _repository = FolderSettingsRepository(ref.read(appDbProvider));

    if (!_repository.folderSettings.containsKey(entity.path)) {
      _repository.update(FolderUISettings(entity: entity, width: 200, detailedView: false, isDropZone: false, showHiddenFiles: false, showFolderButtons: false));
    }
    return _repository.folderSettings[entity.path]!;
  }

  void changeWidth(double delta) {
    state = state.copyWith(width: state.width + delta);

    saveFolderSettings();
  }

  void saveFolderSettings() {
    _repository.update(state);
  }

  void setDetailedView(bool detailedView) {
    if (state.detailedView != detailedView) {
      state = state.copyWith(detailedView: detailedView);
    }
  }

  void setDropZone(bool isDropZone) {
    if (state.isDropZone != isDropZone) {
      state = state.copyWith(isDropZone: isDropZone);
    }
  }

  void showFolderButtons(bool showFolderButtons) {
    if (state.showFolderButtons != showFolderButtons) {
      state = state.copyWith(showFolderButtons: showFolderButtons);
    }
  }

  void showHiddenFiles(bool showHiddenFiles) {
    if (state.showHiddenFiles != showHiddenFiles) {
      state = state.copyWith(showHiddenFiles: showHiddenFiles);
    }
  }
}
