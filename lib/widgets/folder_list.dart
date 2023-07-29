import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';


import '../interfaces/keyboard_callback.dart';
import '../misc/keyboard_handler.dart';
import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../models/folder_ui_settings.dart';
import '../providers/folder_contents.dart';
import '../providers/folder_path.dart';
import '../providers/folder_settings.dart';
import '../providers/metadata.dart';
import '../providers/preview.dart';
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

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(folderContentsProvider(widget.path));
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));
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
          onPerformDrop: (event) => _onPerformDrop(event),
          child: MouseRegion(
            onEnter: (_) => handler.setFocus(true),
            onExit: (_) => handler.setFocus(false),
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
                  child: ListView.builder(
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
                              child: DraggableWidget(
                                  child: Container(
                                      color: selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
                                      child: Row(children: [
                                        FileIcon(entity.path),
                                        Expanded(
                                            child: Text(entity.path.split('/').last,
                                                maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                                      ]))),
                            ));
                      },
                      scrollDirection: Axis.vertical,
                      shrinkWrap: true),
                ),
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

  DropOperation _onDropOver(DropOverEvent event) {
    final item = event.session.items.first;
    if (item.canProvide(Formats.fileUri)) {
      return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
    }
    return DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (reader.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          Uri toFileUri = Uri.parse('${widget.path.uri}${basename(Uri.decodeComponent(uri.path))}');

          final type = await FileSystemEntity.type(Uri.decodeComponent(uri.path));
          switch (type) {
            case FileSystemEntityType.file:
              moveFile(File.fromUri(uri), Uri.decodeComponent(toFileUri.path));
              break;
            case FileSystemEntityType.directory:
              moveDirectory(Directory.fromUri(uri), Uri.decodeComponent(toFileUri.path));
              break;
            default:
              if (Link(uri.path).existsSync()) {
                debugPrint('got a link, what now?');
              }
              break;
          }
        }
      });
    }
  }

  void _selectEntry(List <FileOfInterest> entities, int index) {
    FileOfInterest entity = entities[index];

    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(widget.path, entity.entity as Directory);
    }

    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    if (handler.isIndividualMultiSelectionPressed()) {
      selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
    } else if (handler.isBlockMultiSelectionPressed()) {
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

      selectedEntities.clear();
      if (entity.isFile) {
        selectedEntities.add(entity);
      } else if (entity.isDirectory) {
        // We only preselect folder entities if the preview pane is open on the assumption that this is what the user will be expecting.
        if (ref.read(previewProvider).visible) {
          Set<FileOfInterest> selectedFiles = {};

          Directory d = Directory(entity.path);
          for (var e in d.listSync()) {
            FileOfInterest foi = FileOfInterest(entity: e);
            if (foi.canPreview) {
              selectedFiles.add(foi);
            }
          }
          selectedEntities.addAll(selectedFiles);
        }
      }
    }
  }

  @override
  void delete() {

  }

  @override
  void left() {

  }

  @override
  void right() {

  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    selectedEntities.addAll(entities.toSet());
  }
}