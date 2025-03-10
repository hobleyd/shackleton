import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/models/file_of_interest.dart';

import 'contents/folder_contents.dart';

part 'editing_entity.g.dart';

@Riverpod(keepAlive: true)
class EditingEntity extends _$EditingEntity {
  @override
  FileOfInterest? build() {
    return null;
  }

  void setEditingEntity(Directory path, FileOfInterest? entity) {
    FolderContents contents = ref.read(folderContentsProvider(path.path).notifier);
    if (entity != null) {
      contents.setEditableState(entity, true);
    } else {
      if (state != null) {
        contents.setEditableState(state!, false);
      }
    }

    state = entity;
  }
}


