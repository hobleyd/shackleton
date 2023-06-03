import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/folder_ui_settings.dart';

part 'folder_settings.g.dart';

@riverpod
class FolderSettings extends _$FolderSettings {
  @override
  FolderUISettings build(FileSystemEntity entity) {
    return FolderUISettings(entity: entity);
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
