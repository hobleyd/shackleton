import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
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

Future<FileOfInterest?> createZip(FileOfInterest folder, Set<FileOfInterest> filesToZip) async {
  if (filesToZip.isEmpty) {
    return null;
  }
  debugPrint('creating zip file');
  FileOfInterest foi = FileOfInterest(entity: getZipName(folder, filesToZip));
  var encoder = ZipFileEncoder();
  debugPrint('creating encoder for ${foi.path}');
  encoder.create(foi.path, level: Deflate.BEST_COMPRESSION);
  for (var file in filesToZip) {
    if (file.isDirectory) {
      encoder.addDirectory(file.entity as Directory, includeDirName: true);
    }
    else if (file.isFile) {
      encoder.addFile(file.entity as File);
    }
  }
  debugPrint('closing $foi');
  encoder.close();
  return foi;
}

FileOfInterest getEntity(String path) {
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.directory) {
    return FileOfInterest(entity: Directory(path));
  }

  return FileOfInterest(entity: File(path));
}

File getZipName(FileOfInterest folder, Set<FileOfInterest> filesToZip) {
  if (filesToZip.length == 1) {
    String name = filesToZip.first.path;
    if (name.contains('.')) {
      name = name.replaceRange(name.lastIndexOf('.'), null, '.zip');
    } else {
      name += '.zip';
    }

    debugPrint('new zip file name is: $name');
    return File(join(folder.path, name));
  }

  // Multiple files.
  String prefix = 'Archive';
  File output = File(join(folder.path, '$prefix.zip'));
  int version = 1;
  while (output.existsSync()) {
    output = File(join(folder.path, '$prefix-${version++}.zip'));
  }
  debugPrint('new zip file name is: ${output.path}');

  return output;
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

