import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

import '../interfaces/keyboard_callback.dart';
import '../misc/keyboard_handler.dart';
import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../models/folder_ui_settings.dart';
import '../providers/file_events.dart';
import '../providers/contents/folder_contents.dart';
import '../providers/contents/selected_folder_contents.dart';
import '../providers/folder_path.dart';
import '../providers/metadata.dart';
import '../repositories/folder_settings_repository.dart';
import 'entity_context_menu.dart';

class FolderList extends ConsumerStatefulWidget {
  final Directory path;

  const FolderList({super.key, required this.path});

  @override
  ConsumerState<FolderList> createState() => _FolderList();
}

class _FolderList extends ConsumerState<FolderList> implements KeyboardCallback {
  late List<FileOfInterest> entities;
  late KeyboardHandler handler;
  bool isDropZone = false;
  bool showFolderButtons = false;

  int _lastSelectedItemIndex = -1;
  int _lastSelectedTimestamp = -1;

  get folderPath => widget.path;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(folderContentsProvider(folderPath));

    return Consumer(builder: (context, watch, child) {
      var folderSettings = ref.watch(folderSettingsRepositoryProvider(folderPath.path));
      return folderSettings.when(error: (error, stackTrace) {
        return Text('Failed to get settings', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (FolderUISettings folderSettings) {
        return SizedBox(width: folderSettings.width, child: Row(children: [
          Expanded(
            child: DropRegion(
              formats: Formats.standardFormats,
              hitTestBehavior: HitTestBehavior.opaque,
              onDropOver: (event) {
                return _onDropOver(event);
              },
              onDropEnter: (event) {
                setState(() {
                  isDropZone = true;
                });
              },
              onDropLeave: (event) {
                setState(() {
                  isDropZone = false;
                });
              },
              onPerformDrop: (event) => _onPerformDrop(event, destination: FileOfInterest(entity: folderPath)),
              child: MouseRegion(
                onEnter: (_) {
                  handler.hasFocus = true;
                  setState(() {
                    showFolderButtons = true;
                  });
                },
                onExit: (_) {
                  handler.hasFocus = false;
                  setState(() {
                    showFolderButtons = false;
                  });
                },
                child: Container(
                  alignment: Alignment.topLeft,
                  decoration: isDropZone
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
                    folder: FileOfInterest(entity: folderPath),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                      child: Column(
                        children: [
                          _getFolderColumnHeaders(context, folderSettings),
                          Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 2, margin: const EdgeInsets.only(left: 8.0)),
                          Expanded(child: _getListView(folderSettings)),
                          _getFolderSettingsIcons(folderSettings),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              key: const Key('resize'),
              child: GestureDetector(
                onHorizontalDragUpdate: (DragUpdateDetails details) async {
                  var folderNotifier = ref.read(folderSettingsRepositoryProvider(folderPath.path).notifier);
                  folderNotifier.updateSettings(folderSettings.copyWith(width: folderSettings.width + details.delta.dx));

                  // Resize the window if we are resizing the rightmost FolderList and it is butted up against the right hand side of the window.
                  if (mounted) {
                    Size windowSize = await windowManager.getSize();
                    double widgetPosition = _getWidgetPosition(context)!.right;

                    if (widgetPosition > windowSize.width - 10) {
                      windowManager.setSize(Size(windowSize.width + details.delta.dx, windowSize.height));
                    }
                  }
                },
                child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3, margin: const EdgeInsets.only(right: 6),),
              )),
        ]),
        );
      });
    });
  }

  @override
  void dispose() {
    handler.deregister();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    handler = KeyboardHandler(ref: ref, keyboardCallback: this, name: 'FolderList');
    handler.register();
  }

  Widget _getEntityRow(BuildContext context, FileOfInterest entity, bool showDetails) {
    TextEditingController tagController = TextEditingController();
    tagController.text = entity.name;
    tagController.selection = TextSelection(baseOffset: 0, extentOffset: entity.extensionIndex);

    return Row(
      children: [
        FileIcon(entity.path),
        if (entity.editing) ...[
          Expanded(
            child: TextField(
                autofocus: true,
                controller: tagController,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true,),
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
        ],
        if (!entity.editing) ...[
          Expanded(
            child: Text(entity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
        if (showDetails) ...[
          SizedBox(width: 40, child: Text(getEntitySizeString(entity: entity, decimals: 0), textAlign: TextAlign.right, style: Theme.of(context).textTheme.bodySmall),),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: Text(DateFormat('dd MMM yyyy HH:mm').format(entity.stat.modified), style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.right),),
        ],
        const SizedBox(width:10),
      ],
    );
  }

  Widget _getEntityWidget(BuildContext context, FileOfInterest entity, bool showDetails) {
    if (entity.isDirectory) {
      return DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            _selectIfValidDropLocation(context, event, entity);
            return _onDropOver(event);
          },
          onDropEnter: (event) {},
          onDropLeave: (event) {},
          onPerformDrop: (event) => _onPerformDrop(event, destination: entity),
          child: _getEntityRow(context, entity, showDetails));
    }

    return _getEntityRow(context, entity, showDetails);
  }

  Widget _getFolderSettingsIcons(FolderUISettings settings) {
    var folderNotifier = ref.read(folderSettingsRepositoryProvider(folderPath.path).notifier);
    return showFolderButtons
        ? Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
                  iconSize: 14,
                  onPressed: () => folderNotifier.updateSettings(settings.copyWith(detailedView: !settings.detailedView)),
                  padding: const EdgeInsets.only(top: 5),
                  splashRadius: 0.0001,
                  tooltip: settings.detailedView ? 'Show simple file list' : 'Show detailed file list',
                  icon: Icon(settings.detailedView ? Icons.list_outlined : Icons.view_week),
                ),
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
                  iconSize: 14,
                  onPressed: () => folderNotifier.updateSettings(settings.copyWith(showHiddenFiles: !settings.showHiddenFiles)),
                  padding: const EdgeInsets.only(top: 5),
                  splashRadius: 0.0001,
                  tooltip: settings.showHiddenFiles ? 'Hide hidden files' : 'Show hidden files',
                  icon: Icon(settings.showHiddenFiles ? Icons.hdr_weak : Icons.hdr_strong),
                ),
                const Spacer(),
                IconButton(
                  constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
                  iconSize: 14,
                  onPressed: () => newEntity(),
                  padding: const EdgeInsets.only(top: 5),
                  splashRadius: 0.0001,
                  tooltip: 'New folder...',
                  icon: const Icon(Icons.create_new_folder),
                ),
                const Spacer(),
              ],
            ),
          )
        : const SizedBox(height: 1);
  }

  Widget _getFolderColumnHeaders(BuildContext context, folderSettings) {
    var entitiesNotifier = ref.read(folderContentsProvider(folderPath).notifier);

    Widget sortIcon = entitiesNotifier.getSortOrder() == EntitySortOrder.asc ? const Icon(Icons.expand_less) : const Icon(Icons.expand_more);

    return Row(children: [
      Expanded(
        child: TextButton.icon(
          onPressed: () => entitiesNotifier.sortBy(EntitySortField.name),
          icon: entitiesNotifier.getSortField() == EntitySortField.name ? sortIcon : const Icon(Icons.remove),
          label: Text('Name', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
      if (folderSettings.detailedView) ...[
        SizedBox(
          width: 80,
          child: TextButton.icon(
            onPressed: () => entitiesNotifier.sortBy(EntitySortField.size),
            icon: entitiesNotifier.getSortField() == EntitySortField.size ? sortIcon : const Icon(Icons.remove),
            label: Text('Size', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 120,
          child: TextButton.icon(
            onPressed: () => entitiesNotifier.sortBy(EntitySortField.modified),
            icon: entitiesNotifier.getSortField() == EntitySortField.modified ? sortIcon : const Icon(Icons.remove),
            label: Text('Modified', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
      ],
    ]);
  }

  Widget _getListView(FolderUISettings settings) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedFolderContentsProvider);
    List<FileOfInterest> entityList = List.from(entities);
    entityList.removeWhere((element) => !settings.showHiddenFiles && element.isHidden == true);

    List<GlobalKey?> keys = List.filled(entityList.length, null, growable: false);

    return SingleChildScrollView(
        child: ListView.builder(
        itemCount: entityList.length,
        itemBuilder: (context, index) {
          FileOfInterest entity = entityList[index];
          keys[index] = GlobalKey<DragItemWidgetState>();
          return InkWell(
              onTap: () => _selectEntry(context, entityList, index),
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
                    // Dragging multiple items is possible, but requires us to return the list of DragItemWidgets from each individual Draggable.
                    // So, we need to loop over selectedEntities and find the DragItemWidget that relates to this entity using the list of
                    // GlobalKeys we created with the ListView.builder to extract the correct DragItem out.
                    List<DragItemWidgetState> dragItems = [];
                    for (var e in selectedEntities) {
                      var itemIndex = entityList.indexOf(e);
                      // if we double click on a file to open it, this will get called, but the selectedEntities will be related to the parent
                      // folder; so double check that the index exists to avoid an Exception.
                      if (itemIndex != -1) {
                        dragItems.add(keys[itemIndex]!.currentState! as DragItemWidgetState);
                      }
                    }
                    return dragItems;
                  },
                  child: Container(
                          color: selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
                          child: _getEntityWidget(context, entity, settings.detailedView)
                        ),
                      ),
              ),
          );
        },
        scrollDirection: Axis.vertical,
        shrinkWrap: true),
    );
  }

  Rect? _getWidgetPosition(BuildContext context) {
    final renderObject = context.findRenderObject();
    final matrix = renderObject?.getTransformTo(null);

    if (matrix != null && renderObject?.paintBounds != null) {
      final rect = MatrixUtils.transformRect(matrix, renderObject!.paintBounds);
      return rect;
    } else {
      return null;
    }
  }

  void _selectIfValidDropLocation(BuildContext context, DropOverEvent event, FileOfInterest destination) {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (item.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          if (destination.isDirectory) {
            FileOfInterest source = FileOfInterest(entity: Directory.fromUri(uri));
            if (source.isValidMoveLocation(destination.path)) {
              _selectEntry(context, entities, entities.indexOf(destination), shouldEditName: false);
              return;
            }
          }
          ref.read(selectedFolderContentsProvider.notifier).removeAll();
        }
      });
    }
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final item = event.session.items.first;
    if (item.canProvide(Formats.fileUri)) {
      return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
    }
    return DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event, {required FileOfInterest destination}) async {
    if (event.session.items.isNotEmpty) {
      for (var item in event.session.items) {
        final reader = item.dataReader!;
        if (reader.canProvide(Formats.fileUri)) {
          reader.getValue(Formats.fileUri, (uri) async {
            if (uri != null) {
              Uri toFileUri = Uri.parse('${destination.uri}${basename(Uri.decodeComponent(uri.path))}');

              final type = FileSystemEntity.typeSync(Uri.decodeComponent(uri.path));
              var _ = switch (type) {
                FileSystemEntityType.file => FileOfInterest(entity: File.fromUri(uri)).moveFile(Uri.decodeComponent(toFileUri.path)),
                FileSystemEntityType.directory => FileOfInterest(entity: Directory.fromUri(uri)).moveDirectory(Uri.decodeComponent(toFileUri.path)),
                _ => FileOfInterest(entity: Link.fromUri(uri)).moveLink(Uri.decodeComponent(toFileUri.path)),
              };
            }
          });
        }
      }
    }
  }

  void _renameFile(FileOfInterest entity, String filename) {
    FolderContents contents = ref.read(folderContentsProvider(folderPath).notifier);
    contents.setEditableState(entity, false);
    handler.setEditing(false);

    entity.rename(filename);
  }

  void _selectEntry(BuildContext context, List <FileOfInterest> entities, int index, {bool shouldEditName = true}) {
    FileOfInterest entity = entities[index];

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    // Add the selected Directory into the visible folder list.
    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(widget.path, entity.entity as Directory);
    }

    var selectedFolderContents = ref.read(selectedFolderContentsProvider.notifier);
    if (handler.isIndividualMultiSelectionPressed) {
      selectedFolderContents.contains(entity) ? selectedFolderContents.remove(entity) : selectedFolderContents.add(entity);    } else if (handler.isBlockMultiSelectionPressed) {
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
          selectedFolderContents.add(entities[i]);
        }
      }
    } else {
      int currentTimestamp = DateTime.now().millisecondsSinceEpoch;
      if (_lastSelectedItemIndex == index) {
        if (currentTimestamp - _lastSelectedTimestamp < 2000) {
          if (shouldEditName) {
            FolderContents contents = ref.read(folderContentsProvider(folderPath).notifier);
            contents.setEditableState(entity, true);
            handler.setEditing(true);
          }
        } else {
          selectedFolderContents.replace(entity);
        }
      } else {
        _lastSelectedItemIndex = index;
        selectedFolderContents.replace(entity);
      }
      _lastSelectedTimestamp = currentTimestamp;
    }

    Scrollable.ensureVisible(context);
  }

  @override
  void delete() {
    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.deleteAll(ref.watch(selectedFolderContentsProvider));
  }

  @override
  void down() {

  }

  @override
  void exit() {
    if (handler.isEditing) {
      FileOfInterest entity = entities[_lastSelectedItemIndex];
      FolderContents contents = ref.read(folderContentsProvider(folderPath).notifier);
      contents.setEditableState(entity, false);
      handler.setEditing(false);
    }
  }

  @override
  void left() {

  }

  @override
  void newEntity() {
    FolderContents contents = ref.read(folderContentsProvider(folderPath).notifier);
    FileOfInterest entity = FileOfInterest(entity: widget.path.createTempSync('new-'), editing: true);
    contents.add(entity);
    handler.setEditing(true);
  }

  @override
  void right() {

  }

  @override
  void up() {

  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedFolderContentsProvider.notifier);
    selectedEntities.addAll(entities.toSet());

  }
}