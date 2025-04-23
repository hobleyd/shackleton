import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart';
import 'package:path/path.dart' as path;
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../models/file_of_interest.dart';

DropOperation onDropOver(DropOverEvent event) {
  final item = event.session.items.first;
  if (item.canProvide(Formats.fileUri)) {
    return event.session.allowedOperations.contains(DropOperation.move) ? DropOperation.move : DropOperation.none;
  }
  return DropOperation.none;
}

Future<void> onPerformDrop(PerformDropEvent event, {required FileOfInterest destination}) async {
  if (event.session.items.isNotEmpty) {
    for (var item in event.session.items) {
      final reader = item.dataReader!;
      if (reader.canProvide(Formats.fileUri)) {
        reader.getValue(Formats.fileUri, (uri) async {
          if (uri != null) {
            String fromPath = uri.toFilePath(windows: Platform.isWindows);
            String finalPath = path.join(destination.path, basename(fromPath));

            final type = FileSystemEntity.typeSync(fromPath);
            debugPrint('entity type: $type, $fromPath, ${destination.path}');
            var _ = switch (type) {
              FileSystemEntityType.file => FileOfInterest(entity: File(fromPath)).moveFile(finalPath),
              FileSystemEntityType.directory => FileOfInterest(entity: Directory(fromPath)).moveDirectory(finalPath),
              _ => FileOfInterest(entity: Link(fromPath)).moveLink(finalPath),
            };
          }
        });
      }
    }
  }
}