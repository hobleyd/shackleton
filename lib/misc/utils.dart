import 'dart:io';

import 'package:path/path.dart';

import '../models/file_of_interest.dart';

void copyDirectory(Directory source, Directory destination) {
  for (var entity in source.listSync(recursive: false)) {
    if (entity is Directory) {
      var newDirectory = Directory(join(destination.absolute.path, basename(entity.path)));
      newDirectory.createSync();

      copyDirectory(entity.absolute, newDirectory);
    } else if (entity is File) {
      entity.copySync(join(destination.path, basename(entity.path)));
    }
  }
}

FileOfInterest getEntity(String path) {
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.directory) {
    return FileOfInterest(entity: Directory(path));
  }

  return FileOfInterest(entity: File(path));
}

Future<Directory> moveDirectory(Directory source, String destination) async {
  try {
    // prefer using rename as it is probably faster
    return await source.rename(destination);
  } on FileSystemException {
    // if rename fails, recursively copy the directory and all it's contents.
    copyDirectory(source, Directory(destination));
    source.delete(recursive: true);
    return source;
  }
}

Future<File> moveFile(File sourceFile, String newPath) async {
  try {
    return await sourceFile.rename(newPath);
  } on FileSystemException {
    final newFile = await sourceFile.copy(newPath);
    await sourceFile.delete();
    return newFile;
  }
}
