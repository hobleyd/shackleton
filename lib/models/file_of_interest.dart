import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:process_run/process_run.dart';
import 'package:url_launcher/url_launcher.dart';

import '../misc/utils.dart';
import '../models/tag.dart';
import '../providers/metadata.dart';

const Set<String> documentExtensions = { 'pdf' };
const Set<String> imageExtensions = { 'jpeg', 'jpg', 'png', 'tiff' };
const Set<String> videoExtensions = { 'gif' };

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
  get isDirectory => entity.statSync().type == FileSystemEntityType.directory;
  get isFile => entity.statSync().type == FileSystemEntityType.file;
  get isImage => imageExtensions.contains(extension);
  get isHidden => entity.path.split('/').last.startsWith('.');
  get isMetadataSupported => imageExtensions.contains(extension);
  get name => basename(path);
  get path => entity.path;
  get uri => entity.uri;

  @override
  bool operator ==(other) => other is FileOfInterest && entity.path == other.entity.path;

  @override
  int compareTo(other) => path.compareTo(other.path);

  Future<void> cacheFileOfInterest(WidgetRef ref) async {
    if (isDirectory) {
      Directory d = entity as Directory;
      for (var entity in d.listSync()) {
        await FileOfInterest(entity: entity).cacheFileOfInterest(ref);
      }
    } else {
      var metadata = ref.read(metadataProvider(this).notifier);
      Set<Tag> tags = await metadata.getTagsFromFile(this);
      await metadata.replaceTags(this, tags, update: false);
    }
  }

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

  FileOfInterest copyWith({FileSystemEntity? entity, bool? editing}) {
    return FileOfInterest(
      entity: entity ?? this.entity,
      editing: editing ?? this.editing,
    );
  }

  void delete() async {
    if (Platform.isMacOS) {
      String trash = join(getHomeFolder(), '.Trash', basename(path));

      if (isDirectory) {
        moveDirectory(trash);
      } else {
        moveFile(trash);
      }
    } else {
      entity.deleteSync();
    }
  }

  Future<void> importImagesFromFolder(WidgetRef ref) async {
    if (isDirectory) {
      Directory d = entity as Directory;
      for (var entity in d.listSync()) {
        await FileOfInterest(entity: entity).importImagesFromFolder(ref);
      }
    } else if (isFile && isImage){
      String destinationPath = await _getPathInLibrary();
      File libraryEntity = _getFile(destinationPath);

      if (!libraryEntity.existsSync() || getFileSha256(libraryEntity) != getFileSha256(entity as File)) {
        await moveFile(destinationPath);
      }
      await FileOfInterest(entity: libraryEntity).cacheFileOfInterest(ref);
    }
  }

  Future<Directory> moveDirectory(String destination) async {
    Directory dir = entity as Directory;
    try {
      // prefer using rename as it is probably faster
      return await dir.rename(destination);
    } on FileSystemException {
      // if rename fails, recursively copy the directory and all it's contents.
      copyDirectory(dir, Directory(destination));
      dir.delete(recursive: true);
      return dir;
    }
  }

  Future<File> moveFile(String newPath) async {
    File file = entity as File;
    try {
      return file.rename(newPath);
    } on FileSystemException {
      final newFile = await file.copy(newPath);
      await entity.delete();
      return newFile;
    }
  }

  Future<Link> moveLink(String newPath) async {
    Link sourceLink = entity as Link;
    try {
      return await sourceLink.rename(newPath);
    } on FileSystemException {
      final newLink = Link(newPath);
      newLink.createSync(sourceLink.targetSync());
      return newLink;
    }
  }

  Future openFile() async {
    if (await canLaunchUrl(entity.uri)) {
      launchUrl(entity.uri);
    }
  }

  void rename(String name) {
    entity.rename(join(dirname(path), name));
  }

  @override
  String toString() {
    return name;
  }

  File _getFile(String destinationPath) {
    Directory parentFolder = Directory(dirname(destinationPath));
    if (!parentFolder.existsSync()) {
      parentFolder.createSync(recursive: true);
    }

    return File(destinationPath);
  }

  Future<String> _getPathInLibrary() async {
    if (isImage && exists) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-CreateDate', path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          // Create Date: 2016:06:26 14:46:58
          String creationDate = output.stdout;
          DateTime creationDateTime = DateFormat("yyyy:MM:dd HH:mm:ss").parse(creationDate);
          String year = DateFormat('yyyy').format(creationDateTime);
          String month = DateFormat('MM - MMMM').format(creationDateTime);
          return join(getHomeFolder(), 'Pictures', year, month, name);
        }
      }
    }

    return "";
  }
}