import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../misc/app_intents.dart';
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
  final FocusNode _focusNode = FocusNode();
  ScrollController scrollController = ScrollController();
  List<GlobalKey?> keys = [];
  int lastVisibleRow = 0;

  GridController get gridController => widget.gridController;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MapSettings map = ref.watch(mapPaneProvider);
    List<FileOfInterest> entities = ref.watch(gridContentsProvider);

    keys = List.filled(entities.length, null, growable: false);

    return Shortcuts(
      shortcuts: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): const NavigateLeftIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): const NavigateLeftIntent(),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): const NavigateLeftIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight): const NavigateRightIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): const NavigateRightIntent(),
        const SingleActivator(LogicalKeyboardKey.tab): const NavigateRightIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp): const NavigateUpIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): const NavigateUpIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown): const NavigateDownIntent(),
        const SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): const NavigateDownIntent(),
        const SingleActivator(LogicalKeyboardKey.backspace): const DeleteIntent(),
        const SingleActivator(LogicalKeyboardKey.delete): const DeleteIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const ExitIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true): const SelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): const SelectAllIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, meta: true): const NewEntityIntent(),
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): const NewEntityIntent(),
      },
      child: Actions(
        actions: {
          NavigateLeftIntent: CallbackAction<NavigateLeftIntent>(onInvoke: (_) => gridController.left()),
          NavigateRightIntent: CallbackAction<NavigateRightIntent>(onInvoke: (_) => gridController.right()),
          NavigateUpIntent: CallbackAction<NavigateUpIntent>(onInvoke: (_) => gridController.up()),
          NavigateDownIntent: CallbackAction<NavigateDownIntent>(onInvoke: (_) => gridController.down()),
          DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: (_) => gridController.delete()),
          ExitIntent: CallbackAction<ExitIntent>(onInvoke: (_) => gridController.exit()),
          SelectAllIntent: CallbackAction<SelectAllIntent>(onInvoke: (_) => gridController.selectAll()),
          NewEntityIntent: CallbackAction<NewEntityIntent>(onInvoke: (_) => gridController.newEntity()),
        },
        child: MouseRegion(
          onEnter: (_) => _focusNode.requestFocus(),
          child: Focus(
            focusNode: _focusNode,
            child: LayoutBuilder(
              builder: (context, constraints) {
                gridController.gridColumns = switch (constraints.maxWidth) { < 1024 => 3, < 2048 => 5, _ => 7 };
                gridController.visibilityCallback = _ensureSelectedItemVisible;

                return GridView.builder(
                  controller: scrollController,
                  cacheExtent: 2000,
                  itemCount: entities.length,
                  itemBuilder: (context, idx) {
                    keys[idx] = GlobalKey<DragItemWidgetState>();

                    return GestureDetector(
                        onTap: () => gridController.selectEntityByMouse(idx),
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
                                  final selectedEntities = ref.read(selectedGridEntitiesProvider);
                                  List<DragItemWidgetState> dragItems = [];
                                  for (var e in selectedEntities) {
                                    var itemIndex = entities.indexOf(e);
                                    if (itemIndex != -1 && keys[itemIndex] != null && keys[itemIndex]!.currentState != null) {
                                      dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                                    }
                                  }
                                  return dragItems;
                                },
                                child: EntityPreview(
                                  entity: entities[idx],
                                  displayMetadata: true,
                                  previewWidth: (MediaQuery.of(context).size.width - 210 - map.width) / gridController.gridColumns,
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
          ),
        ),
      ),
    );
  }

  void _ensureSelectedItemVisible(int idx) {
    int visibleRow = (idx / gridController.gridColumns).floor();

    GlobalKey? key = keys[idx];
    if (key != null) {
      var columnHeight = key.currentState!.context.size!.height;
      if (visibleRow != lastVisibleRow) {
        scrollController.animateTo(columnHeight * visibleRow, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
        lastVisibleRow = visibleRow;
      }
    }
  }

  void _previewEntities(FileOfInterest tappedEntity) {
    final selected = ref.read(selectedGridEntitiesProvider);
    if (selected.length > 1 && selected.contains(tappedEntity)) {
      // Multi-selection: navigate only the selected items (keep selection as-is).
    } else {
      // Single item or outside selection: clear so the pane navigates all grid items.
      ref.read(selectedGridEntitiesProvider.notifier).removeAll();
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => PreviewPane(initialEntity: tappedEntity,)));
  }
}
