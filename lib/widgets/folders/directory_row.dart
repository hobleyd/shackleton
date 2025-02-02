import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../misc/drag_drop.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/selected_folder_contents.dart';
import 'entity_row.dart';
import 'selection.dart';

class DirectoryRow extends ConsumerWidget {
  final FileOfInterest entity;
  final bool showDetailedView;
  final KeyboardHandler handler;
  final List<FileOfInterest> entities;

  const DirectoryRow({super.key, required this.entity, required this.handler, required this.showDetailedView, required this.entities});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropRegion(
        formats: Formats.standardFormats,
        hitTestBehavior: HitTestBehavior.opaque,
        onDropOver: (event) {
          _selectIfValidDropLocation(ref, event, entity);
          return onDropOver(event);
        },
        onDropEnter: (event) {},
        onDropLeave: (event) {},
        onPerformDrop: (event) => onPerformDrop(event, destination: entity),
        child: EntityRow(entity: entity, handler: handler, showDetailedView: showDetailedView));
  }

  void _selectIfValidDropLocation(WidgetRef ref, DropOverEvent event, FileOfInterest destination) {
    final item = event.session.items.first;
    final reader = item.dataReader!;
    if (item.canProvide(Formats.fileUri)) {
      reader.getValue(Formats.fileUri, (uri) async {
        if (uri != null) {
          if (destination.isDirectory) {
            FileOfInterest source = FileOfInterest(entity: Directory.fromUri(uri));
            if (source.isValidMoveLocation(destination.path)) {
              selectEntry(ref: ref, handler: handler, path: destination.entity as Directory, entities: entities, index: entities.indexOf(destination));
              return;
            }
          }
          ref.read(selectedFolderContentsProvider.notifier).removeAll();
        }
      });
    }
  }
}