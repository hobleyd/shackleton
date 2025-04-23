import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../misc/drag_drop.dart';
import '../../models/file_of_interest.dart';
import 'entity_row.dart';
import 'folder_pane_controller.dart';


class DirectoryRow extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool showDetailedView;
  final FolderPaneController paneController;
  final List<FileOfInterest> entities;

  const DirectoryRow({super.key, required this.entity, required this.paneController, required this.showDetailedView, required this.entities});

  @override
  ConsumerState<DirectoryRow> createState() => _DirectoryRow();
}

class _DirectoryRow extends ConsumerState<DirectoryRow> {
  bool isDropZone = false;

  get entity => widget.entity;
  get showDetailedView => widget.showDetailedView;
  get paneController => widget.paneController;
  get entities => widget.entities;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
        formats: Formats.standardFormats,
        hitTestBehavior: HitTestBehavior.opaque,
        onDropOver: (event) {
          return onDropOver(event);
        },
        onDropEnter: (event) async {
          _selectIfValidDropLocation(ref, event, entity);
        },
        onDropLeave: (event) async {
          setState(() {
            isDropZone = false;
          });
        },
        onPerformDrop: (event) => onPerformDrop(event, destination: entity),
        child: Container(
          alignment: Alignment.topLeft,
          decoration: isDropZone
              ? BoxDecoration(shape: BoxShape.rectangle, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.teal, width: 2,),)
              : null,
          child: EntityRow(entity: entity, paneController: paneController, showDetailedView: showDetailedView),
    ));
  }
  
  void _selectIfValidDropLocation(WidgetRef ref, DropEvent event, FileOfInterest destination) {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (item.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          if (destination.isDirectory) {
            FileOfInterest source = FileOfInterest(entity: Directory.fromUri(uri));
            if (source.isValidMoveLocation(destination.path)) {
              paneController.selectEntityByEntity(destination);
              setState(() {
                isDropZone = true;
              });
            }
          }
          //ref.read(selectedFolderContentsProvider.notifier).removeAll();
        }
      });
    }
  }
}