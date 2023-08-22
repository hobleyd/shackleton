import 'dart:ffi';
import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';


import '../interfaces/keyboard_callback.dart';
import '../misc/keyboard_handler.dart';
import '../models/file_of_interest.dart';
import '../models/folder_ui_settings.dart';
import '../providers/folder_contents.dart';
import '../providers/folder_path.dart';
import '../providers/folder_settings.dart';
import '../providers/metadata.dart';
import '../providers/selected_entities.dart';
import 'entity_context_menu.dart';

class FolderList extends ConsumerStatefulWidget {
  final Directory path;

  const FolderList({Key? key, required this.path}) : super(key: key);

  @override
  ConsumerState<FolderList> createState() => _FolderList();
}

class _FolderList extends ConsumerState<FolderList> implements KeyboardCallback {
  late List<FileOfInterest> entities;
  late KeyboardHandler handler;

  int _lastSelectedItemIndex = -1;
  int _lastSelectedTimestamp = -1;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(folderContentsProvider(widget.path));
    FolderUISettings folderSettings = ref.watch(folderSettingsProvider(widget.path));
    var fsNotifier = ref.read(folderSettingsProvider(widget.path).notifier);

    return Row(children: [
      Expanded(
        child: DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            fsNotifier.setDropZone(true);
            return _onDropOver(event);
          },
          onDropEnter: (event) {
            fsNotifier.setDropZone(true);
          },
          onDropLeave: (event) {
            fsNotifier.setDropZone(false);
          },
          onPerformDrop: (event) => _onPerformDrop(event, destination: widget.path),
          child: MouseRegion(
            onEnter: (_) {
              handler.hasFocus = true;
              fsNotifier.showFolderButtons(true);
            },
            onExit: (_) {
              handler.hasFocus = false;
              fsNotifier.showFolderButtons(false);
            },
            child: Container(
              alignment: Alignment.topLeft,
              decoration: folderSettings.isDropZone
                  ? BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.teal,
                        width: 2,
                      ),
                    )
                  : null,
              child: EntityContextMenu(
                fileType: FileType.folderList,
                folder: FileOfInterest(entity: widget.path),
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                  child: Column(
                    children: [
                      Expanded(child: folderSettings.detailedView ? _getComplexGridView(context) : _getSimpleListView()),
                      _getFolderIcons(folderSettings),
                    ],
                  ),),
              ),
            ),
          ),
        ),
      ),
      MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              fsNotifier.changeWidth(details.delta.dx);
            },
            child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
          )),
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

  void _addSelectedEntity(FileOfInterest entity) {
    var folderListSelection = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    folderListSelection.add(entity);

    // We want to add selected entities to both the folder list selection, and the preview grid.
    var previewGridSelection = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
    if (entity.canPreview) {
      previewGridSelection.add(entity);
    } else if (entity.isDirectory) {
      Set<FileOfInterest> selectedFiles = {};

      Directory d = Directory(entity.path);
      for (var e in d.listSync()) {
        FileOfInterest foi = FileOfInterest(entity: e);
        if (foi.canPreview) {
          selectedFiles.add(foi);
        }
      }
      previewGridSelection.addAll(selectedFiles);
    }
  }

  _clearSelectedEntities() {
    var folderListSelection = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    folderListSelection.clear();

    var previewGridSelection = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
    previewGridSelection.clear();
  }

  Widget _getEditableEntity(BuildContext context, FileOfInterest entity) {
    TextEditingController tagController = TextEditingController();
    tagController.text = entity.name;
    tagController.selection = TextSelection(baseOffset: 0, extentOffset: entity.extensionIndex);

    return Row(children: [
      FileIcon(entity.path),
      Expanded(
        child: TextField(
            autofocus: true,
            controller: tagController,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
            keyboardType: TextInputType.text,
            maxLines: 1,
            onSubmitted: (tags) => _renameFile(entity, tagController.text),
            style: Theme.of(context).textTheme.bodySmall),
      ),
      IconButton(
          icon: const Icon(Icons.save),
          constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
          iconSize: 12,
          padding: EdgeInsets.zero,
          splashRadius: 0.0001,
          tooltip: 'Rename file...',
          onPressed: () => _renameFile(entity, tagController.text)),
      const SizedBox(width: 9), // Allow space for scrollbar.
    ]);
  }

  Widget _getEntityRow(BuildContext context, FileOfInterest entity) {
    return Row(
      children: [
        FileIcon(entity.path),
        Expanded(
          child: Text(entity.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }

  Widget _getFolderIcons(FolderUISettings settings) {
    return settings.showFolderButtons
        ? Row(
              children: [
                const Spacer(),
                IconButton(
                  onPressed: () => ref.read(folderSettingsProvider(widget.path).notifier).setDetailedView(!settings.detailedView),
                  tooltip: settings.detailedView ? 'Show simple file list' : 'Show detailed file list',
                  icon: Icon(settings.detailedView ? Icons.more_vert : Icons.more_horiz),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => ref.read(folderSettingsProvider(widget.path).notifier).showHiddenFiles(!settings.showHiddenFiles),
                  tooltip: settings.showHiddenFiles ? 'Hide hidden files' : 'Show hidden files',
                  icon: Icon(settings.showHiddenFiles ? Icons.hdr_weak : Icons.hdr_strong),
                ),
                const Spacer(),
              ],
            )
        : const SizedBox(height: 1);
  }

  Widget _getNonEditableEntity(BuildContext context, FileOfInterest entity) {
    if (entity.isDirectory) {
      return DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            _selectEntry(entities, entities.indexOf(entity), editing: false);
            return _onDropOver(event);
          },
          onDropEnter: (event) {},
          onDropLeave: (event) {},
          onPerformDrop: (event) => _onPerformDrop(event, destination: entity.entity as Directory),
          child: _getEntityRow(context, entity));
    }

    return _getEntityRow(context, entity);
  }

  Widget _getComplexGridView(BuildContext context) {
    handler.deregister();
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));
    List<PlutoColumn> columns = [
      PlutoColumn(title: 'name', field: 'name', type: PlutoColumnType.text(), width: 200),
      PlutoColumn(title: 'size', field: 'size', type: PlutoColumnType.number(), width: 80, textAlign: PlutoColumnTextAlign.right),
      PlutoColumn(title: 'modified', field: 'modified', type: PlutoColumnType.time(), width: 150),
    ];

    List<PlutoRow> rows = entities.map((entity) => PlutoRow(
      cells: {
        'name': PlutoCell(value: entity),
        'size': PlutoCell(value: entity.stat.size),
        'modified': PlutoCell(value: DateFormat('yyyy-MM-dd\tHH:mm:ss').format(entity.stat.modified)),
      },
      checked: selectedEntities.contains(entity),
    )).toList();

    return PlutoGrid(
        columns: columns,
        configuration: PlutoGridConfiguration(
          style: PlutoGridStyleConfig(
            enableCellBorderVertical: true,
            enableColumnBorderVertical: true,
            enableCellBorderHorizontal: false,
            cellTextStyle: Theme.of(context).textTheme.bodySmall!,
            columnTextStyle: Theme.of(context).textTheme.labelSmall!,
            defaultCellPadding: const EdgeInsets.symmetric(horizontal: 5),
            defaultColumnFilterPadding: const EdgeInsets.symmetric(horizontal: 5),
            defaultColumnTitlePadding: const EdgeInsets.symmetric(horizontal: 5),
            rowHeight: 20,
          ),
        ),
        mode: PlutoGridMode.multiSelect,
        onSelected: (PlutoGridOnSelectedEvent event) => _addSelectedEntity(event.cell!.value),
        onRowDoubleTap: (var event) => event.cell.value.openFile(),
        rows: rows,
      );
  }

  Widget _getSimpleListView() {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));

    return ListView.builder(
        itemCount: entities.length,
        itemBuilder: (context, index) {
          FileOfInterest entity = entities[index];

          return InkWell(
              onTap: () => _selectEntry(entities, index),
              onDoubleTap: () => entity.openFile(),
              child: DragItemWidget(
                allowedOperations: () => [DropOperation.move],
                canAddItemToExistingSession: true,
                dragItemProvider: (request) async {
                  final item = DragItem();
                  item.add(Formats.fileUri(entity.uri));
                  item.add(Formats.htmlText.lazy(() => entity.path));
                  return item;
                },
                child: entity.editing
                    ? _getEditableEntity(context, entity)
                    : DraggableWidget(
                        child: Container(
                          color: selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
                          child: _getNonEditableEntity(context, entity)
                        ),
                      ),
              ),
          );
        },
        scrollDirection: Axis.vertical,
        shrinkWrap: true);
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final item = event.session.items.first;
    if (item.canProvide(Formats.fileUri)) {
      return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
    }
    return DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event, {required Directory destination}) async {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (reader.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          Uri toFileUri = Uri.parse('${destination.uri}${basename(Uri.decodeComponent(uri.path))}');

          final type = await FileSystemEntity.type(Uri.decodeComponent(uri.path));
          var fse = switch (type) {
            FileSystemEntityType.file      => FileOfInterest(entity: File.fromUri(uri)).moveFile(Uri.decodeComponent(toFileUri.path)),
            FileSystemEntityType.directory => FileOfInterest(entity: Directory.fromUri(uri)).moveDirectory(Uri.decodeComponent(toFileUri.path)),
            _                              => FileOfInterest(entity: Link.fromUri(uri)).moveLink(Uri.decodeComponent(toFileUri.path)),
          };
        }
      });
    }
  }

  void _renameFile(FileOfInterest entity, String filename) {
    FolderContents contents = ref.read(folderContentsProvider(widget.path).notifier);
    contents.setEditableState(entity, false);
    handler.setEditing(false);

    entity.rename(filename);
  }

  void _selectEntry(List <FileOfInterest> entities, int index, {bool editing = true}) {
    FileOfInterest entity = entities[index];

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    // Add the selected Directory into the visible folder list.
    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(widget.path, entity.entity as Directory);
    }

    if (handler.isIndividualMultiSelectionPressed) {
      _toggleSelectedEntity(entity);
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
          _addSelectedEntity(entities[i]);
        }
      }
    } else {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (_lastSelectedItemIndex == index) {
        if (currentTimestamp - _lastSelectedTimestamp < 2000) {
          if (editing) {
            // We want to edit the name....
            FolderContents contents = ref.read(folderContentsProvider(widget.path).notifier);
            contents.setEditableState(entity, true);
            handler.setEditing(true);
          }
        } else {
          _toggleSelectedEntity(entity, reset: true);
        }
      } else {
        _lastSelectedItemIndex = index;

        _clearSelectedEntities();
        _addSelectedEntity(entity);
      }
      _lastSelectedTimestamp = currentTimestamp;
    }
  }

  void _toggleSelectedEntity(FileOfInterest entity, {bool reset = false}) {
    var folderListSelection = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    var previewGridSelection = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);

    if (folderListSelection.contains(entity)) {
      if (reset) {
        folderListSelection.removeAll();
        previewGridSelection.removeAll();
      } else {
        folderListSelection.remove(entity);
        previewGridSelection.remove(entity);
      }
    } else {
      folderListSelection.add(entity);
      previewGridSelection.add(entity);
    }
  }

  @override
  void delete() {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    selectedEntities.deleteAll();
  }

  @override
  void exit() {
    if (handler.isEditing) {
      FileOfInterest entity = entities[_lastSelectedItemIndex];
      FolderContents contents = ref.read(folderContentsProvider(widget.path).notifier);
      contents.setEditableState(entity, false);
      handler.setEditing(false);
    }
  }

  @override
  void left() {

  }

  @override
  void newEntity() {
    FolderContents contents = ref.read(folderContentsProvider(widget.path).notifier);
    FileOfInterest entity = FileOfInterest(entity: widget.path.createTempSync('new-'), editing: true);
    contents.add(entity);
    handler.setEditing(true);
  }

  @override
  void right() {

  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    selectedEntities.addAll(entities.toSet());

    var gridEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
    gridEntities.addAll(entities.toSet());
  }
}