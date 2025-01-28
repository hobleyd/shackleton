import 'dart:io';

import 'package:path/path.dart';
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