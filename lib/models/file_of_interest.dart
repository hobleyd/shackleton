import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

const Set<String> imageExtensions = { 'jpg', 'tiff' };

@immutable
class FileOfInterest extends Comparable {
  final FileSystemEntity entity;

  FileOfInterest({required this.entity});

  @override
  get hashCode => entity.path.hashCode;
  get isDirectory => entity.statSync().type == FileSystemEntityType.directory;
  get isFile => entity.statSync().type == FileSystemEntityType.file;
  get isHidden => entity.path.split('/').last.startsWith('.');
  get isImage => imageExtensions.contains(entity.path.split('.').last);
  get path => entity.path;
  get uri => entity.uri;

  @override
  bool operator ==(other) => other is FileOfInterest && entity.path == other.entity.path;

  @override
  int compareTo(other) => path.compareTo(other.path);

  Future openFile() async {
    if (await canLaunchUrl(entity.uri)) {
      launchUrl(entity.uri);
    }
  }

  @override
  String toString() {
    return entity.path;
  }
}