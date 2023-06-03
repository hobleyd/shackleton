import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';


import '../models/file_of_interest.dart';
import '../models/folder_ui_settings.dart';
import '../misc/utils.dart';
import '../providers/folder_contents.dart';
import '../providers/folder_path.dart';
import '../providers/folder_settings.dart';
import '../providers/metadata.dart';
import '../providers/preview.dart';
import '../providers/selected_entities.dart';

class FolderList extends ConsumerStatefulWidget {
  final Directory path;

  const FolderList({Key? key, required this.path}) : super(key: key);

  @override
  ConsumerState<FolderList> createState() => _FolderList();
}

class _FolderList extends ConsumerState<FolderList> {
  bool _isCtrlKeyPressed = false;
  bool _isShiftKeyPressed = false;
  int _lastSelectedItemIndex = -1;

  @override
  Widget build(BuildContext context) {
    List<FileOfInterest> entities = ref.watch(folderContentsProvider(widget.path));
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
                child: Container(
                alignment: Alignment.topLeft,
                decoration: folderSettings.isDropZone
                    ? BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal, width: 2,),
                      )
                    : null,

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
                                          Expanded(child: Text(entity.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                                      ]))),
                                ));
                          },
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true),
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
    RawKeyboard.instance.removeListener(_handleKeyEvent);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    RawKeyboard.instance.addListener(_handleKeyEvent);
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

  void _handleKeyEvent(RawKeyEvent event) {
    // Update key state based on key events
    if (event is RawKeyDownEvent) {
      if (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.altLeft || event.logicalKey == LogicalKeyboardKey.altRight)) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        debugPrint('setting alt key pressed to true');
        _isCtrlKeyPressed = true;

      } else if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
        debugPrint('folderList: setting ctrl key pressed to true');
          _isCtrlKeyPressed = true;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _isShiftKeyPressed = true;
      }
    } else if (event is RawKeyUpEvent) {
      if (Platform.isMacOS && (event.logicalKey == LogicalKeyboardKey.altLeft || event.logicalKey == LogicalKeyboardKey.altRight)) {
        // MacOS insists that Ctrl can be used with the left mouse button to simulate a right click. Single Button mice were a bad idea
        // when Steve Jobs insisted on them and who has seen one in the last 10 years. Seriously Apple?
        debugPrint('setting alt key pressed to false');
        _isCtrlKeyPressed = true;

      } else if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
        debugPrint('folderList: setting ctrl key pressed to false');
          _isCtrlKeyPressed = false;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _isShiftKeyPressed = false;
      }
    }
  }

  void _selectEntry(List <FileOfInterest> entities, int index) {
    FileOfInterest entity = entities[index];

    debugPrint('Key state: $_isShiftKeyPressed, $_isCtrlKeyPressed, $_lastSelectedItemIndex');
    // Cancel editing in the PreviewGrid if we are making selections.
    ref.read(metadataProvider(entity).notifier).setEditable(false);

    if (entity.isDirectory) {
      ref.read(folderPathProvider.notifier).addFolder(widget.path, entity.entity as Directory);
    }

    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList).notifier);
    if (_isCtrlKeyPressed) {
      selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
    } else if (_isShiftKeyPressed) {
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

      debugPrint(entity.toString());
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
            if (ref.read(metadataProvider(foi).notifier).isMetadataSupported(foi)) {
              selectedFiles.add(foi);
            }
          }
          selectedEntities.addAll(selectedFiles);
        }
      }
    }
  }
}