import 'dart:io';

import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';

import '../notifiers/folder.dart';

class FolderList extends StatefulWidget {
  final Directory path;

  const FolderList({Key? key, required this.path}) : super(key: key);

  @override
  _FolderList createState() => _FolderList();
}

class _FolderList extends State<FolderList> {
  bool _isCtrlKeyPressed = false;
  bool _isShiftKeyPressed = false;
  int _lastSelectedItemIndex = -1;

  @override
  Widget build(BuildContext context) {
    return Consumer<Folder>(builder: (context, model, child) {
      model.entities[widget.path] ?? model.getFolderContents(widget.path);

      return Row(children: [
        Expanded(
            child: DropRegion(
                formats: Formats.standardFormats,
                hitTestBehavior: HitTestBehavior.opaque,
                onDropOver: (event) {
                  model.getSettings(widget.path).isDropZone = true;
                  return _onDropOver(event);
                },
                onDropEnter: (event) {
                  model.setDropZone(widget.path, true);
                },
                onDropLeave: (event) {
                  model.setDropZone(widget.path, false);
                },
                onPerformDrop: (event) => _onPerformDrop(event, model),
                child: Container(
                alignment: Alignment.topLeft,
                decoration: model.getSettings(widget.path).isDropZone
                    ? BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.teal, width: 2,),
                      )
                    : null,

                    child: Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                      child: ListView.builder(
                          itemCount: model.entities[widget.path]?.length ?? 0,
                          itemBuilder: (context, index) {
                            FileSystemEntity entity = model.entities[widget.path]![index];

                            return InkWell(
                                onTap: () => _selectEntry(model, index),
                                onDoubleTap: () => _openFile(model, index),
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
                                        color: model.selectedEntities.contains(entity) ? Colors.lime : Colors.transparent,
                                        child: Row(children: [
                                          FileIcon(entity.path),
                                          Expanded(child: Text(entity.path.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall)),
                                      ]))),
                                ));
                          },
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true),
                    )))),
        MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (DragUpdateDetails details) {
                model.setFolderWidth(widget.path, details.delta.dx);
              },
              child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
            )),
      ]);
    });
  }

  @override
  void dispose() {
    RawKeyboard.instance.removeListener(_handleKeyEvent);

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    // Add key event listeners
    RawKeyboard.instance.addListener(_handleKeyEvent);
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final item = event.session.items.first;
    if (item.canProvide(Formats.fileUri)) {
      return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
    }
    return DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event, Folder model) async {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (reader.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          Uri toFileUri = Uri.parse('${widget.path.uri}${basename(Uri.decodeComponent(uri.path))}');

          final type = await FileSystemEntity.type(Uri.decodeComponent(uri.path));
          switch (type) {
            case FileSystemEntityType.file:
              _moveFile(File.fromUri(uri), Uri.decodeComponent(toFileUri.path));
              break;
            case FileSystemEntityType.directory:
              _moveDirectory(Directory.fromUri(uri), Uri.decodeComponent(toFileUri.path));
              break;
            default:
              if (Link(uri.path).existsSync()) {
                debugPrint('got a link, what now?');
              }
              break;
          }

          // Refresh both listings to show the moved FileSystemEntity.
          Directory d = model.entities.where((dir, settings) => dir.path == dirname(uri.path)).keys.first;
          model.refreshFolder(widget.path);
          model.refreshFolder(d);
        }
      });
    }
  }

  void _copyDirectory(Directory source, Directory destination) =>
      source.listSync(recursive: false)
          .forEach((var entity) {
        if (entity is Directory) {
          var newDirectory = Directory(join(destination.absolute.path, basename(entity.path)));
          newDirectory.createSync();

          _copyDirectory(entity.absolute, newDirectory);
        } else if (entity is File) {
          entity.copySync(join(destination.path, basename(entity.path)));
        }
      });

  void _handleKeyEvent(RawKeyEvent event) {
    // Update key state based on key events
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
          _isCtrlKeyPressed = true;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _isShiftKeyPressed = true;
      }
    } else if (event is RawKeyUpEvent) {
      if (event.logicalKey == LogicalKeyboardKey.controlLeft || event.logicalKey == LogicalKeyboardKey.controlRight) {
          _isCtrlKeyPressed = false;
      } else if (event.logicalKey == LogicalKeyboardKey.shiftLeft || event.logicalKey == LogicalKeyboardKey.shiftRight) {
          _isShiftKeyPressed = false;
      }
    }
  }

  Future<Directory> _moveDirectory(Directory source, String destination) async {
    try {
      // prefer using rename as it is probably faster
      return await source.rename(destination);
    } on FileSystemException catch (e) {
      // if rename fails, recursively copy the directory and all it's contents.
      _copyDirectory(source, Directory(destination));
      source.delete(recursive: true);
      return source;
    }
  }

  Future<File> _moveFile(File sourceFile, String newPath) async {
    try {
      // prefer using rename as it is probably faster
      return await sourceFile.rename(newPath);
    } on FileSystemException catch (e) {
      // if rename fails, copy the source file and then delete it
      final newFile = await sourceFile.copy(newPath);
      await sourceFile.delete();
      return newFile;
    }
  }

  Future _openFile(Folder model, int index) async {
    FileSystemEntity entity = model.entities[widget.path]![index];
    if (await canLaunchUrl(entity.uri)) {
      launchUrl(entity.uri);
    }
  }

  void _selectEntry(Folder model, int index) {
    FileSystemEntity entity = model.entities[widget.path]![index];
    if (entity.statSync().type == FileSystemEntityType.directory) {
      model.addFolder(widget.path, Directory(entity.path));
    }

    if (_isCtrlKeyPressed) {
      if (model.selectedEntities.contains(entity)) {
        model.removeSelection(entity);
      } else {
        model.addSelection(entity);
      }
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
          model.addSelection(model.entities[widget.path]![i]);
        }
      }
    } else {
      if (entity.statSync().type == FileSystemEntityType.file) {
        model.selectedEntities.clear();
        model.addSelection(entity);
        _lastSelectedItemIndex = index;
      }
    }
  }
}