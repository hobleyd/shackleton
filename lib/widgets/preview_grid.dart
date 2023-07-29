import 'dart:io';

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
  final FileType type;

  const PreviewGrid({Key? key, required this.columnCount, required this.type}) : super(key: key);

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> implements KeyboardCallback {
  late List<FileOfInterest> entities;
  late KeyboardHandler handler;

  final PageController _controller = PageController();
  int _lastSelectedItemIndex = -1;

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
                  onEnter: (_) => handler.hasFocus = true,
                  onExit: (_) => handler.hasFocus = false,
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
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      color: Colors.grey,
      child: Stack(
      children: [
         PageView.builder(
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
        Align(
          alignment: Alignment.center,
          child: Row(
            children: [
              IconButton(
                  onPressed: () => left(),
                  icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28.0)),
              const Spacer(),
              IconButton(
                  onPressed: () => right(),
                  icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28.0)),
            ],
          ),
        ),
      ],
    ),
    );
  }

  void _previewEntities(FileOfInterest tappedEntity) {
    var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);

    if (!selectedEntities.contains(tappedEntity)) {
      // If we double tap on an unselectedEntity, assume we want to clear the selection.
      var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
      selectedEntities.replace(tappedEntity);
    }

    // TODO: Ideally this would be a new window, but Flutter doesn't support multiple windows yet, refactor when it does.
    Navigator.push(context, MaterialPageRoute(builder: (context) => const PreviewPane()));
  }

  void _selectEntity(FileOfInterest entity) {
    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    int index = entities.indexOf(entity);
    var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
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

  }

  @override
  void exit() {
    Navigator.of(context, rootNavigator: true).maybePop(context);
  }

  @override
  void left() {
    if (widget.columnCount == 1) {
      if (_lastSelectedItemIndex != 0) _controller.previousPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  @override
  void right() {
    if (widget.columnCount == 1) {
      if (_lastSelectedItemIndex < entities.length - 1) _controller.nextPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedEntitiesProvider(widget.type == FileType.folderList ? FileType.previewGrid : FileType.previewPane).notifier);
    selectedEntities.addAll(entities.toSet());
  }
}
