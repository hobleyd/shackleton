import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/editing_entity.dart';

import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../providers/folder_path.dart';
import '../../providers/metadata.dart';

int _lastSelectedItemIndex = -1;
int _lastSelectedTimestamp = -1;

void selectEntry({required WidgetRef ref, required KeyboardHandler handler, required Directory path, required List <FileOfInterest> entities, required int index, bool shouldEditName = true}) {
  FileOfInterest entity = entities[index];

  // Cancel editing in the PreviewGrid if we are making selections.
  ref.read(metadataProvider(entity).notifier).setEditable(false);

  // Add the selected Directory into the visible folder list.
  if (entity.isDirectory) {
    ref.read(folderPathProvider.notifier).addFolder(path, entity.entity as Directory);
  }

  var selectedFolderContents = ref.read(selectedFolderContentsProvider.notifier);
  if (handler.isIndividualMultiSelectionPressed) {
    selectedFolderContents.contains(entity) ? selectedFolderContents.remove(entity) : selectedFolderContents.add(entity);
  } else if (handler.isBlockMultiSelectionPressed) {
    if (_lastSelectedItemIndex != -1) {
      int start = _lastSelectedItemIndex;
      int end = index;

      if (start > end) {
        final temp = start;
        start = end;
        end = temp;
      }

      for (int i = start; i <= end; i++) {
        selectedFolderContents.add(entities[i]);
      }
    }
  } else {
    int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
    if (_lastSelectedItemIndex == index) {
      if (currentTimestamp - _lastSelectedTimestamp < 2000) {
        if (shouldEditName) {
          ref.read(editingEntityProvider.notifier).setEditingEntity(path, entity);
          handler.setEditing(true);
        }
      } else {
        selectedFolderContents.replace(entity);
      }
    } else {
      _lastSelectedItemIndex = index;
      selectedFolderContents.replace(entity);
    }
    _lastSelectedTimestamp = currentTimestamp;
  }
}