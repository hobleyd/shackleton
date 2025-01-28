import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/misc/keyboard_handler.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import 'directory_row.dart';
import 'entity_row.dart';
import 'selection.dart';

class FolderPane extends ConsumerStatefulWidget {
  final Directory path;
  final bool showHiddenFiles;
  final bool showDetailedView;
  final KeyboardHandler handler;

  const FolderPane({super.key, required this.path, required this.showHiddenFiles, required this.showDetailedView, required this.handler});

  @override
  ConsumerState<FolderPane> createState() => _FolderPane();
}

class _FolderPane extends ConsumerState<FolderPane> {
  late List<FileOfInterest> entities;
  late Set<FileOfInterest> selectedEntities;


  get folderPath => widget.path;
  get handler => widget.handler;
  get showHiddenFiles => widget.showHiddenFiles;
  get showDetailedView => widget.showDetailedView;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(folderContentsProvider(folderPath));
    selectedEntities = ref.watch(selectedFolderContentsProvider);

    List<FileOfInterest> entityList = List.from(entities);
    entityList.removeWhere((element) => !showHiddenFiles && element.isHidden == true);

    List<GlobalKey?> keys = List.filled(entityList.length, null, growable: false);

    return SingleChildScrollView(
      child: ListView.builder(
          itemCount: entityList.length,
          itemBuilder: (context, index) {
            FileOfInterest entity = entityList[index];
            keys[index] = GlobalKey<DragItemWidgetState>();
            return InkWell(
              onTapUp: (tap) => selectEntry(ref: ref, handler: handler, path: folderPath, entities: entityList, index: index),
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
                      var itemIndex = entityList.indexOf(entity);
                      dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                    } else {
                      // Dragging multiple items is possible, but requires us to return the list of DragItemWidgets from each individual Draggable.
                      // So, we need to loop over selectedEntities and find the DragItemWidget that relates to this entity using the list of
                      // GlobalKeys we created with the ListView.builder to extract the correct DragItem out.
                      for (var e in selectedEntities) {
                        var itemIndex = entityList.indexOf(e);
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
                          ? DirectoryRow(entity: entity, handler: handler, showDetailedView: showDetailedView, entities: entities)
                          : EntityRow(entity: entity, handler: handler, showDetailedView: showDetailedView),
                  ),
                ),
              ),
            );
          },
          scrollDirection: Axis.vertical,
          shrinkWrap: true),
    );
  }
}