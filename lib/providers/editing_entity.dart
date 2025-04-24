import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';
import 'contents/folder_contents.dart';

part 'editing_entity.g.dart';

@Riverpod(keepAlive: true)
class EditingEntity extends _$EditingEntity {
  @override
  FileOfInterest? build() {
    return null;
  }

  void setEditingEntity(FileOfInterest entity, bool isEditing) {
    ref.read(folderContentsProvider(entity.parent.path).notifier).setEditableState(entity, isEditing);

    state = isEditing ? entity : null;
  }
}


