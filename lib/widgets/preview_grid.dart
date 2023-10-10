import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
  const PreviewGrid({Key? key}) : super(key: key);

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> implements KeyboardCallback {
  late List<FileOfInterest> entities;
  late KeyboardHandler handler;

  int _lastSelectedItemIndex = -1;

  // TODO: Add key navigation
  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.previewGrid));
    entities = selectedEntities.toList();
    entities.removeWhere((element) => !element.canPreview);
    entities.sort();

    return entities.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text(
              selectedEntities.isNotEmpty ? 'Your selected files are not previewable (yet), sorry' : 'Select one or more files to preview!',
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
            const SizedBox(width: 200, child: MetadataEditor(completeListType: FileType.previewGrid, selectedListType: FileType.previewPane,)),
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
    var selectedEntities = ref.watch(selectedEntitiesProvider(FileType.previewPane));
    List<GlobalKey?> keys = List.filled(entities.length, null, growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          itemCount: entities.length,
          itemBuilder: (context, index) {
            keys[index] = GlobalKey<DragItemWidgetState>();

            return InkWell(
                onTap: () => _selectEntity(entities[index]),
                onDoubleTap: () => _previewEntities(entities[index]),
                child: DragItemWidget(
                    key: keys[index],
                    allowedOperations: () => [DropOperation.move],
                    canAddItemToExistingSession: true,
                    dragItemProvider: (request) async {
                      final item = DragItem();
                      item.add(Formats.fileUri(entities[index].uri));
                      item.add(Formats.htmlText.lazy(() => entities[index].path));
                      return item;
                    },
                    child: DraggableWidget(
                      dragItemsProvider: (context) {
                        // Dragging multiple items is possible, but requires us to return the list of DragItemWidgets from each individual Draggable.
                        // So, we need to loop over selectedEntities and find the DragItemWidget that relates to this entity using the list of
                        // GlobalKeys we created with the ListView.builder to extract the correct DragItem out.
                        List<DragItemWidgetState> dragItems = [];
                        for (var e in selectedEntities) {
                          var itemIndex = entities.indexOf(e);
                          // if we double click on a file to open it, this will get called, but the selectedEntities will be related to the parent
                          // folder; so double check that the index exists to avoid an Exception.
                          if (itemIndex != -1 && keys[itemIndex] != null) {
                            dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                          }
                        }
                        return dragItems;
                      },
                      child: EntityPreview(
                        entity: entities[index],
                        selectionType: FileType.previewPane,
                      ),
                    )));
          },
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: switch (constraints.maxWidth) { < 1024 => 3, < 2048 => 5, _ => 7 },
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          padding: const EdgeInsets.only(left: 20, right: 20),
          primary: false,
        );
      },
    );
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
