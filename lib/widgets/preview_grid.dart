import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/keyboard_callback.dart';
import '../misc/keyboard_handler.dart';
import '../models/file_of_interest.dart';
import '../providers/metadata.dart';
import '../providers/selected_entities.dart';
import 'entity_preview.dart';
import 'entity_context_menu.dart';
import 'metadata_editor.dart';
import 'preview_pane.dart';

class PreviewGrid extends ConsumerStatefulWidget {
  final int columnCount;

  const PreviewGrid({Key? key, required this.columnCount}) : super(key: key);

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> implements KeyboardCallback {
  final ScrollController _controller = ScrollController();
  late List<FileOfInterest> entities;
  late KeyboardHandler handler;

  int _lastSelectedItemIndex = -1;

  // TODO: Add buttons to rotate the selected image(s)
  // TODO: Add key navigation
  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.previewGrid));
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
                child: MouseRegion(
                  onEnter: (_) => handler.hasFocus = true,
                  onExit: (_) => handler.hasFocus = false,
                  child: _getGridView(),
                ),
              ),
            ),
            const VerticalDivider(),
            SizedBox(width: 200, child: MetadataEditor(completeListType: FileType.previewGrid, selectedListType: FileType.previewPane,)),
          ]);
  }

  @override
  void dispose() {
    handler.deregister();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    handler = KeyboardHandler(ref: ref, keyboardCallback: this);
    handler.register();
  }

  Widget _getGridView() {
    return GridView.count(
        controller: _controller,
        crossAxisCount: widget.columnCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        padding: const EdgeInsets.only(left: 20, right: 20),
        primary: false,
        children: entities.map((e) =>
            GestureDetector(
                onTap: () => _selectEntity(e),
                onDoubleTap: () => _previewEntities(e),
                child: EntityPreview(
                  entity: e,
                  selectionType: FileType.previewPane,
                )
            )
        ).toList());
  }

  void _previewEntities(FileOfInterest tappedEntity) {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewPane).notifier);
    if (!selectedEntities.contains(tappedEntity)) {
      // If we double tap on an unselectedEntity, assume we want to browse everything in detail.
      selectAll();
    }

    // TODO: Ideally this would be a new window, but Flutter doesn't support multiple windows yet, refactor when it does.
    Navigator.push(context, MaterialPageRoute(builder: (context) => PreviewPane(initialEntity: tappedEntity,)));
  }

  void _selectEntity(FileOfInterest entity) {
    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    int index = entities.indexOf(entity);
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewPane).notifier);
    if (handler.isIndividualMultiSelectionPressed) {
      selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
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
          selectedEntities.add(entities[i]);
        }
      }
    } else {
      _lastSelectedItemIndex = index;
      selectedEntities.replace(entity);
    }
  }

  @override
  void delete() {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewPane).notifier);
    selectedEntities.deleteAll();
  }

  @override
  void exit() {
    Navigator.of(context, rootNavigator: true).maybePop(context);
  }

  @override
  void left() {
    if (_lastSelectedItemIndex > 0) {
      _selectEntity(entities[--_lastSelectedItemIndex]);
    }
  }

  @override
  void right() {
    if (_lastSelectedItemIndex < entities.length) {
      _selectEntity(entities[++_lastSelectedItemIndex]);
    }
  }

  @override
  void newEntity() {

  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewPane).notifier);
    selectedEntities.addAll(entities.toSet());
  }
}
