import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/models/folder_ui_settings.dart';
import 'package:shackleton/widgets/folders/folder_pane_controller.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:window_manager/window_manager.dart';

import '../../misc/drag_drop.dart';
import '../../models/file_of_interest.dart';
import '../../repositories/folder_settings_repository.dart';
import '../entity_context_menu.dart';
import 'folder_column_headers.dart';
import 'folder_pane.dart';
import 'folder_settings_icons.dart';

class FolderDropZone extends ConsumerStatefulWidget {
  final Directory path;
  final FolderUISettings settings;

  const FolderDropZone({super.key, required this.path, required this.settings, });

  @override
  ConsumerState<FolderDropZone> createState() => _FolderDropZone();
}

class _FolderDropZone extends ConsumerState<FolderDropZone> {
  late FolderPaneController paneController;

  bool isDropZone = false;
  bool showFolderButtons = false;
  late double width;

  get folderPath => widget.path;
  get folderSettings => widget.settings;

  @override
  Widget build(BuildContext context) {

    return SizedBox(width: width, child: Row(children: [
      Expanded(
        child: DropRegion(
          formats: Formats.standardFormats,
          hitTestBehavior: HitTestBehavior.opaque,
          onDropOver: (event) {
            return onDropOver(event);
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
          onPerformDrop: (event) => onPerformDrop(event, destination: FileOfInterest(entity: folderPath)),
          child: MouseRegion(
            onEnter: (_) {
              paneController.hasFocus = true;
              setState(() {
                showFolderButtons = true;
              });
            },
            onExit: (_) {
              paneController.hasFocus = false;
              setState(() {
                showFolderButtons = false;
              });
            },
              child: Container(
                alignment: Alignment.topLeft,
                decoration: isDropZone
                    ? BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal, width: 2,),)
                    : null,
                child: EntityContextMenu(
                  folder: FileOfInterest(entity: folderPath),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                    child: Column(
                      children: [
                        FolderColumnHeaders(path: folderPath, showDetailedView: folderSettings.detailedView),
                        Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 2, margin: const EdgeInsets.only(left: 8.0)),
                        Expanded(
                            child: FolderPane(path: folderPath, paneController: paneController, showHiddenFiles: folderSettings.showHiddenFiles, showDetailedView: folderSettings.detailedView)),
                        FolderSettingsIcons(path: folderPath, paneController: paneController, showHiddenFiles: folderSettings.showHiddenFiles, showDetailedView: folderSettings.detailedView),
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
          child: GestureDetector(
            onHorizontalDragEnd: (DragEndDetails details) {
              var folderNotifier = ref.read(folderSettingsRepositoryProvider(folderPath.path).notifier);
              folderNotifier.updateSettings(folderSettings.copyWith(width: width));
            },
            onHorizontalDragUpdate: (DragUpdateDetails details) async {
              setState(() {
                width = width + details.delta.dx;
              });

              // Resize the window if we are resizing the rightmost FolderList and it is butted up against the right hand side of the window,
              // but only to increase the width; we don't want to resize the window smaller.
              if (mounted && folderSettings.width + details.delta.dx > folderSettings.width) {
                double widgetPosition = _getWidgetPosition(context)!.right;
                Size windowSize = await windowManager.getSize();

                if (widgetPosition > windowSize.width - 10) {
                  windowManager.setSize(Size(windowSize.width + details.delta.dx, windowSize.height));
                }
              }
            },
            child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3, margin: const EdgeInsets.only(right: 6),),
          )),
    ]),
    );
  }

  @override @override
  void initState() {
    super.initState();
    paneController = FolderPaneController(context: context, ref: ref, path: folderPath);
    width = folderSettings.width;
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
}