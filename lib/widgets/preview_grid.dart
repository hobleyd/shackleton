import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_of_interest.dart';
import '../providers/metadata.dart';
import '../providers/selected_entities.dart';
import 'entity_preview.dart';
import 'entity_context_menu.dart';
import 'metadata_editor.dart';

class PreviewGrid extends ConsumerStatefulWidget {
  const PreviewGrid({Key? key}) : super(key: key);

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> {
  bool _isCtrlKeyPressed = false;
  bool _isShiftKeyPressed = false;
  int _lastSelectedItemIndex = -1;
  late List<FileOfInterest> entities;

  // TODO: Add buttons to rotate the selected image(s)
  // TODO: Add key navigation
  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));
    entities = selectedEntities.toList();
    entities.removeWhere((element) => !element.canPreview);
    entities.sort();

    return selectedEntities.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Text(
              'Select one or more files to preview!',
              textAlign: TextAlign.center,
            ))
        : Row(children: [
            Expanded(
              child: EntityContextMenu(
                fileType: FileType.previewGrid,
                child: GridView.count(
                    primary: false,
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    crossAxisCount: 5,
                    children: entities
                        .map((e) => GestureDetector(onTap: () => _selectEntity(ref, e), onDoubleTap: () => e.openFile(), child: EntityPreview(entity: e)))
                        .toList()),
              ),
            ),
            const SizedBox(width: 200, child: MetadataEditor()),
          ]);
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  void _handleKeyEvent(RawKeyEvent event) {
    // Update key state based on key events
    if (event is RawKeyDownEvent) {
      if (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.altLeft || event.logicalKey == LogicalKeyboardKey.altRight)) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        debugPrint('setting alt key pressed to true');
        _isCtrlKeyPressed = true;
      } else if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
        debugPrint('setting ctrl key pressed to true');
        _isCtrlKeyPressed = true;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _isShiftKeyPressed = true;
      }
    } else if (event is RawKeyUpEvent) {
      if (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.altLeft || event.logicalKey == LogicalKeyboardKey.altRight)) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        debugPrint('setting alt key pressed to true');
        _isCtrlKeyPressed = false;
      } else if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
        debugPrint('setting ctrl key pressed to false');

        _isCtrlKeyPressed = false;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
        _isShiftKeyPressed = false;
      }
    }
  }

  void _selectEntity(WidgetRef ref, FileOfInterest entity) {
    int index = entities.indexOf(entity);

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
    if (_isCtrlKeyPressed) {
      selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
    } else if (_isShiftKeyPressed) {
      if (_lastSelectedItemIndex != -1) {
        int start = _lastSelectedItemIndex;
        int end = index;

        if (start > end) {
          final temp = start;
          start = end;
          end = temp;
        }

        for (int i = start; i <= end; i++) {
          selectedEntities.add(entities[i]);
        }
      }
    } else {
      _lastSelectedItemIndex = index;
      selectedEntities.replace(entity);
    }
  }
}
