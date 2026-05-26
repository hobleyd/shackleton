import 'dart:io';

import 'package:async/async.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';

import '../misc/utils.dart';
import '../platform/windows_recycle.dart';

const Set<String> documentExtensions = { 'md', 'pdf' };
const Set<String> imageExtensions = { 'gif', 'jpeg', 'jpg', 'png', 'tiff', 'tif' };
const Set<String> videoExtensions = { 'avi', 'm4v', 'mp4', 'mkv', 'mov' };

@immutable
class FileOfInterest implements Comparable {
  final FileSystemEntity entity;
  final bool editing;

  const FileOfInterest({required this.entity, this.editing = false});

  @override
  get hashCode => entity.path.hashCode;
  get canPreview => imageExtensions.contains(extension) || documentExtensions.contains(extension) || videoExtensions.contains(extension);
  get exists => entity.existsSync();
  get extension => entity.path.split('.').last.toLowerCase();
  get extensionIndex => name.lastIndexOf('.') ==  -1 ? name.length : name.lastIndexOf('.');
  get isDirectory => entity is Directory;
  get isFile => entity.statSync().type == FileSystemEntityType.file;
  get isImage => imageExtensions.contains(extension);
  get isLocationSupported => imageExtensions.contains(extension) || videoExtensions.contains(extension);
  get isHidden => name.startsWith('.');
  get isMetadataSupported => imageExtensions.contains(extension) || videoExtensions.contains(extension) || documentExtensions.contains(extension);
  get isVideo => videoExtensions.contains(extension);
  get name => basename(path);
  get path => entity.path;
  get parent => entity.parent;
  get shouldImport => isImage || isVideo;
  get stat => entity.statSync();
  get uri => entity.uri;

  @override
  bool operator ==(other) => other is FileOfInterest && entity.path == other.entity.path;
  Future<bool> different(FileOfInterest other) async => await getFileSha256() != await other.getFileSha256();

  @override
  int compareTo(other) => path.compareTo(other.path);

  void copyDirectory(Directory source, Directory destination) {
    if (source != destination) {
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
  }

  FileOfInterest copyWith({FileSystemEntity? entity, bool? editing}) {
    return FileOfInterest(
      entity: entity ?? this.entity,
      editing: editing ?? this.editing,
    );
  }

  void delete() async {
    String? trash = switch (Platform.operatingSystem) {
      'macos' => join(getHomeFolder(), '.Trash', basename(path)),
      'linux' => join(getHomeFolder(), '.local', 'share', 'Trash', 'files', basename(path)),
            _ => null,
    };

    if (Platform.isWindows) {
      recycleFile(path);
    } else {
      if (trash != null) {
        if (isDirectory) {
          moveDirectory(trash);
        } else {
          moveFile(trash);
        }
      } else {
        entity.deleteSync();
      }
    }
  }

  Future<Digest> getFileSha256() async {
    File file = entity as File;
    final reader = ChunkedStreamReader(file.openRead());
    const chunkSize = 4096;
    var output = AccumulatorSink<Digest>();
    var input = sha256.startChunkedConversion(output);

    try {
      while (true) {
        final chunk = await reader.readChunk(chunkSize);
        if (chunk.isEmpty) {
          break;
        }
        input.add(chunk);
      }
    } finally {
      reader.cancel();
    }

    input.close();

    return output.events.single;
  }

  bool isValidMoveLocation(String destination) {
    if (!FileSystemEntity.isDirectorySync(dirname(destination)))  {
      return false;
    }

    if (entity.path.trimCharRight('/') == destination.trimCharRight('/')) {
      return false;
    }

    if (destination.startsWith(path)) {
      return false;
    }

    return true;
  }

  Future<void> moveDirectory(String destinationPath) async {
    _createParentFolders(destinationPath);

    Directory dir = entity as Directory;
    if (isValidMoveLocation(destinationPath)) {
      try {
        await dir.rename(destinationPath);
      } on FileSystemException {
        copyDirectory(dir, Directory(destinationPath));
        dir.delete(recursive: true);
      }
    }
  }

  File moveFile(String destinationPath) {
    _createParentFolders(destinationPath);

    File file = entity as File;
    try {
      return file.renameSync(destinationPath);
    } on FileSystemException {
      final newFile = file.copySync(destinationPath);
      entity.deleteSync();
      return newFile;
    }
  }

  Future<Link> moveLink(String destinationPath) async {
    _createParentFolders(destinationPath);

    Link sourceLink = entity as Link;
    try {
      return await sourceLink.rename(destinationPath);
    } on FileSystemException {
      final newLink = Link(destinationPath);
      newLink.createSync(sourceLink.targetSync());
      return newLink;
    }
  }

  Future openFile() async {
    if (await canLaunchUrl(entity.uri)) {
      launchUrl(entity.uri);
    }
  }

  FileOfInterest rename(String name) {
    // TODO: fix this for renaming folders.
    if (name == this.name) {
      return this;
    }
    return FileOfInterest(entity: entity.renameSync(join(entity.parent.path, name)));
  }

  @override
  String toString() {
    return '($name)';
  }

  void _createParentFolders(String destinationPath) {
    Directory parentFolder = Directory(dirname(destinationPath));
    if (!parentFolder.existsSync()) {
      parentFolder.createSync(recursive: true);
    }
  }
}
