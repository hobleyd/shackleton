import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import 'directory_row.dart';
import 'entity_row.dart';
import 'folder_pane_controller.dart';

class FolderPane extends ConsumerStatefulWidget {
  final Directory path;
  final bool showHiddenFiles;
  final bool showDetailedView;
  final FolderPaneController paneController;

  const FolderPane({super.key, required this.path, required this.showHiddenFiles, required this.showDetailedView, required this.paneController});

  @override
  ConsumerState<FolderPane> createState() => _FolderPane();
}

class _FolderPane extends ConsumerState<FolderPane> {
  final ItemScrollController scrollController = ItemScrollController();
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  List<GlobalKey?> keys = [];

  get path => widget.path;
  get showHiddenFiles => widget.showHiddenFiles;
  get showDetailedView => widget.showDetailedView;
  get paneController => widget.paneController;

  @override
  Widget build(BuildContext context) {
    List<FileOfInterest> entities = ref.watch(folderContentsProvider(path.path));
    Set<FileOfInterest> selectedEntities = ref.watch(selectedFolderContentsProvider);

    widget.paneController.folderEntities = List.from(entities);
    widget.paneController.folderEntities.removeWhere((element) => !showHiddenFiles && element.isHidden == true);
    widget.paneController.visibilityCallback = _ensureSelectedItemVisible;

    keys = List.filled(paneController.folderEntities.length, null, growable: false);

    return ScrollablePositionedList.builder(
      itemPositionsListener: itemPositionsListener,
      itemScrollController: scrollController,
          itemCount: paneController.folderEntities.length,
          itemBuilder: (context, index) {
            FileOfInterest entity = paneController.folderEntities[index];
            keys[index] = GlobalKey<DragItemWidgetState>();

            return GestureDetector(
              onTapUp: (tap) => paneController.selectEntity(index),
              onDoubleTap: () => entity.openFile(),
              child: DragItemWidget(
                key: keys[index],
                allowedOperations: () => [DropOperation.move],
                canAddItemToExistingSession: true,
                dragItemProvider: (request) async {
                  final item = DragItem();
                  item.add(Formats.fileUri(entity.uri));
                  item.add(Formats.htmlText.lazy(() => entity.path));
                  return item;
                },
                child: DraggableWidget(
                  dragItemsProvider: (context) {
                    List<DragItemWidgetState> dragItems = [];

                    if (!selectedEntities.contains(entity)) {
                      // If the item we are dragging is not in the selectedEntities list, then add it individually for the drag.
                      var itemIndex = paneController.folderEntities.indexOf(entity);
                      dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                    } else {
                      // Dragging multiple items is possible, but requires us to return the list of DragItemWidgets from each individual Draggable.
                      // So, we need to loop over selectedEntities and find the DragItemWidget that relates to this entity using the list of
                      // GlobalKeys we created with the ListView.builder to extract the correct DragItem out.
                      for (var e in selectedEntities) {
                        var itemIndex = paneController.folderEntities.indexOf(e);
                        // if we double click on a file to open it, this will get called, but the selectedEntities will be related to the parent
                        // folder; so double check that the index exists to avoid an Exception.
                        if (itemIndex != -1) {
                          dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                        }
                      }
                    }
                    return dragItems;
                  },
                  child: Container(
                      color: selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
                      child: entity.isDirectory
                          ? DirectoryRow(entity: entity, paneController: paneController, showDetailedView: showDetailedView, entities: entities)
                          : EntityRow(entity: entity, paneController: paneController, showDetailedView: showDetailedView),
                  ),
                ),
              ),
            );
          },
          scrollDirection: Axis.vertical,
          shrinkWrap: true
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
  }

  void _ensureSelectedItemVisible(int idx) {
    int min = itemPositionsListener.itemPositions.value
        .where((ItemPosition position) => position.itemTrailingEdge > 0)
        .reduce((ItemPosition min, ItemPosition position) => position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
        .index;
    int max = itemPositionsListener.itemPositions.value
        .where((ItemPosition position) => position.itemLeadingEdge < 1)
        .reduce((ItemPosition max, ItemPosition position) => position.itemLeadingEdge > max.itemLeadingEdge ? position : max)
        .index;
    if (idx <= min || idx >= max) {
      scrollController.scrollTo(index: idx-1, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
    }
  }
}