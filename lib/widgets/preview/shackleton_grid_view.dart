import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../models/file_of_interest.dart';
import '../../models/map_settings.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/map_pane.dart';
import 'entity_preview.dart';
import 'grid_controller.dart';
import 'preview_pane.dart';

class ShackletonGridView extends ConsumerStatefulWidget {
  final GridController gridController;

  const ShackletonGridView({super.key, required this.gridController, });

  @override
  ConsumerState<ShackletonGridView> createState() => _ShackletonGridView();
}

class _ShackletonGridView extends ConsumerState<ShackletonGridView> {
  ScrollController scrollController = ScrollController();
  List<GlobalKey?> keys = [];
  int lastVisibleRow = 0;

  get gridController => widget.gridController;

  @override
  Widget build(BuildContext context) {
    MapSettings map = ref.watch(mapPaneProvider);
    List<FileOfInterest> entities = ref.watch(gridContentsProvider);
    List<FileOfInterest> selectedEntities = ref.watch(selectedGridEntitiesProvider);

    keys = List.filled(entities.length, null, growable: false);

    return MouseRegion(
      onEnter: (_) => gridController.hasFocus = true,
      onExit: (_) => gridController.hasFocus = false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          gridController.gridColumns = switch (constraints.maxWidth) { < 1024 => 3, < 2048 => 5, _ => 7 };
          gridController.visibilityCallback = _ensureSelectedItemVisible;

          return GridView.builder(
            controller: scrollController,
            itemCount: entities.length,
            itemBuilder: (context, idx) {
              keys[idx] = GlobalKey<DragItemWidgetState>();

              return InkWell(
                  onTap: () => gridController.selectEntity(idx),
                  onDoubleTap: () => _previewEntities(entities[idx]),
                  child: DragItemWidget(
                      key: keys[idx],
                      allowedOperations: () => [DropOperation.move],
                      canAddItemToExistingSession: true,
                      dragItemProvider: (request) async {
                        final item = DragItem();
                        item.add(Formats.fileUri(entities[idx].uri));
                        item.add(Formats.htmlText.lazy(() => entities[idx].path));
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
                              if (itemIndex != -1 && keys[itemIndex] != null && keys[itemIndex]!.currentState != null) {
                                dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                              }
                            }
                            return dragItems;
                          },
                          child: EntityPreview(
                            entity: entities[idx],
                            isSelected: selectedEntities.contains(entities[idx]),
                            displayMetadata: true,
                            previewWidth: (MediaQuery.of(context).size.width - 210 - map.width),
                          ),
                      ),
                  ),
              );
            },
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: gridController.gridColumns, crossAxisSpacing: 10, mainAxisSpacing: 10,),
            padding: const EdgeInsets.only(left: 20, right: 20),
            primary: false,
          );
        },
      ),
    );
  }

  void _ensureSelectedItemVisible(int idx) {
    int visibleRow = (idx / gridController.gridColumns).floor();

    GlobalKey? key = keys[idx];
    if (key != null) {
      var columnHeight = key.currentState!.context.size!.height;
      if (visibleRow != lastVisibleRow) {
        debugPrint('animating to: ${columnHeight * visibleRow}');
        scrollController.animateTo(columnHeight * visibleRow, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
        lastVisibleRow = visibleRow;
      }
    }
  }

  void _previewEntities(FileOfInterest tappedEntity) {
    if (!ref.read(selectedGridEntitiesProvider).contains(tappedEntity)) {
      // If we double tap on an unselectedEntity, replace the selected entities.
      var entityNotifier = ref.read(selectedGridEntitiesProvider.notifier);
      entityNotifier.removeAll();
      entityNotifier.add(tappedEntity);
    }

    // TODO: Ideally this would be a new window, but Flutter doesn't support multiple windows yet, refactor when it does.
    Navigator.push(context, MaterialPageRoute(builder: (context) => PreviewPane(initialEntity: tappedEntity,)));
  }
}