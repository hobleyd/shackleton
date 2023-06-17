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
import 'preview_pane.dart';

class PreviewGrid extends ConsumerStatefulWidget {
  final int columnCount;
  final FileType type;

  const PreviewGrid({Key? key, required this.columnCount, required this.type}) : super(key: key);

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> {
  bool _isIndividualMultiSelectionPressed = false;
  bool _isBlockMultiSelectionPressed = false;
  bool _hasFocus = false;
  final PageController _controller = PageController();

  int _lastSelectedItemIndex = -1;
  late List<FileOfInterest> entities;

  // TODO: Add buttons to rotate the selected image(s)
  // TODO: Add key navigation
  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(widget.type));
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
                fileType: widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane,
                child: MouseRegion(
                  onEnter: (_) => _hasFocus = true,
                  onExit: (_) => _hasFocus = false,
                  child: widget.columnCount == 1 ? _getPageView() : _getGridView(),
                ),
              ),
            ),
            const VerticalDivider(),
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

  Widget _getGridView() {
    return GridView.count(
        primary: false,
        padding: const EdgeInsets.only(left: 20, right: 20),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        crossAxisCount: widget.columnCount,
        children: entities
            .map((e) => GestureDetector(
            onTap: () => _selectEntity(e),
            onDoubleTap: () => _previewEntities(e),
            child: EntityPreview(
              entity: e,
              selectionType: widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane,
            )))
            .toList());
  }
  
  Widget _getPageView() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              _lastSelectedItemIndex = index;
            },
            itemCount: entities.length,
            itemBuilder: (BuildContext context, int pos) {
              return GestureDetector(
                  onTap: () => _selectEntity(entities[pos]),
                  child: EntityPreview(
                    entity: entities[pos],
                    selectionType: widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane,
                  ));
            },
          ),
        ),
        Positioned(
          left: 0.0,
          right: 0.0,
          top: MediaQuery.of(context).size.height * 0.12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                  onPressed: () {
                    // checking if we are not on pos = 0
                    // then we can always go back else do nothing
                    _previousPage();
                  },
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28.0)),
              IconButton(
                  onPressed: () {
                    // checking if we are not on pos = photosList.length - 1
                    // we calculate 0 to length-1
                    // then we can always go forward else do nothing
                    _nextPage();
                  },
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28.0)),
            ],
          ),
        ),
      ],
    );
  }

  KeyEventResult _handleKeyEvent(RawKeyEvent event) {
    if (!_hasFocus) {
      return KeyEventResult.ignored;
    }

    // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
    // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
    bool isCtrlOrMeta = event is RawKeyDownEvent
        ? (Platform.isMacOS && event.isMetaPressed) || (!Platform.isMacOS && event.isControlPressed)
        : (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.metaLeft || event.logicalKey == LogicalKeyboardKey.metaRight))
          ||
          (!Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight));

    if (event is RawKeyDownEvent) {
      if (isCtrlOrMeta) {
        _isIndividualMultiSelectionPressed = true;

        if (event.physicalKey == PhysicalKeyboardKey.keyA) {
          var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
          selectedEntities.addAll(entities.toSet());
        }

        return KeyEventResult.handled;
      } else if (event.isShiftPressed) {
        _isBlockMultiSelectionPressed = true;

        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        if (widget.columnCount == 1) {
          _previousPage();
        }

        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        if (widget.columnCount == 1) {
          _nextPage();
        }

        return KeyEventResult.handled;
      }
    } else if (event is RawKeyUpEvent) {
      if (Platform.isMacOS && isCtrlOrMeta) {
        _isIndividualMultiSelectionPressed = false;

        return KeyEventResult.handled;
      } else if (event.isShiftPressed) {
        _isBlockMultiSelectionPressed = false;

        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        Navigator.of(context, rootNavigator: true).maybePop(context);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  void _nextPage() {
    if (_lastSelectedItemIndex < entities.length - 1) _controller.nextPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
  }

  void _previewEntities(FileOfInterest tappedEntity) {
    var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);

    if (!selectedEntities.contains(tappedEntity)) {
      // If we double tap on an unselectedEntity, assume we want to clear the selection.
      var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
      selectedEntities.replace(tappedEntity);
      debugPrint(selectedEntities.state.toString());
    }

    // TODO: Ideally this would be a new window, but Flutter doesn't support multiple windows yet, refactor when it does.
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviewPane()));
  }

  void _previousPage() {
    if (_lastSelectedItemIndex != 0) _controller.previousPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
  }

  void _selectEntity(FileOfInterest entity) {
    int index = entities.indexOf(entity);

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
    if (_isIndividualMultiSelectionPressed) {
      selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
    } else if (_isBlockMultiSelectionPressed) {
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
