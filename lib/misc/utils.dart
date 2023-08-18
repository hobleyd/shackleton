import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
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

  FileOfInterest foi = FileOfInterest(entity: getZipName(folder, filesToZip));
  var encoder = ZipFileEncoder();
  encoder.create(foi.path, level: Deflate.BEST_COMPRESSION);
  for (var file in filesToZip) {
    if (file.isDirectory) {
      encoder.addDirectory(file.entity as Directory, includeDirName: true);
    }
    else if (file.isFile) {
      encoder.addFile(file.entity as File);
    }
  }
  encoder.close();
  return foi;
}

FileSystemEntity getEntity(String path) {
  if (FileSystemEntity.typeSync(path) == FileSystemEntityType.directory) {
    return Directory(path);
  }

  return File(path);
}

Future<Digest> getFileSha256(File entity) async {
  final reader = ChunkedStreamReader(entity.openRead());
  const chunkSize = 4096;
  var output = AccumulatorSink<Digest>();
  var input = sha256.startChunkedConversion(output);

  try {
    while (true) {
      final chunk = await reader.readChunk(chunkSize);
      if (chunk.isEmpty) {
        // indicate end of file
        break;
      }
      input.add(chunk);
    }
  } finally {
    // We always cancel the ChunkedStreamReader,
    // this ensures the underlying stream is cancelled.
    reader.cancel();
  }

  input.close();

  return output.events.single;
}

String getHomeFolder() {
  return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
}

File getZipName(FileOfInterest folder, Set<FileOfInterest> filesToZip) {
  if (filesToZip.length == 1) {
    String name = filesToZip.first.path;
    if (name.contains('.')) {
      name = name.replaceRange(name.lastIndexOf('.'), null, '.zip');
    } else {
      name += '.zip';
    }

    return File(join(folder.path, name));
  }

  // Multiple files.
  String prefix = 'Archive';
  File output = File(join(folder.path, '$prefix.zip'));
  int version = 1;
  while (output.existsSync()) {
    output = File(join(folder.path, '$prefix-${version++}.zip'));
  }

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

Future<Link> moveLink(Link sourceLink, String newPath) async {
  try {
    return await sourceLink.rename(newPath);
  } on FileSystemException {
    final newLink = Link(newPath);
    newLink.createSync(sourceLink.targetSync());
    return newLink;
  }
}

