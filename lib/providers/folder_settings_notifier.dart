import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/folder_settings.dart';

part 'folder_settings_notifier.g.dart';

@riverpod
class FolderSettingsNotifier extends _$FolderSettingsNotifier {
  @override
  FolderSettings build(FileSystemEntity entity) {
    return FolderSettings(entity: entity);
  }

  void changeWidth(double delta) {
    state = state.copyWith(width: state.width + delta);
  }

  void setDropZone(bool isDropZone) {
    if (state.isDropZone != isDropZone) {
      state = state.copyWith(isDropZone: isDropZone);
    }
  }
}
