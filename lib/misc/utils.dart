import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:async/async.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart';

import '../models/file_of_interest.dart';

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

