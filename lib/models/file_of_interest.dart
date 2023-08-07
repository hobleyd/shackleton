import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:url_launcher/url_launcher.dart';

import '../misc/utils.dart';

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
        moveDirectory(entity as Directory, trash);
      } else {
        moveFile(entity as File, trash);
      }
    } else {
      entity.deleteSync();
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
}