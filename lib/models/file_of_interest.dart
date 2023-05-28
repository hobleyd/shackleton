import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

@immutable
class FileOfInterest {
  final FileSystemEntity entity;

  const FileOfInterest({required this.entity});

  @override
  get hashCode => entity.path.hashCode;
  get isDirectory => entity.statSync().type == FileSystemEntityType.directory;
  get isFile => entity.statSync().type == FileSystemEntityType.file;
  get path => entity.path;
  get uri => entity.uri;

  @override
  bool operator ==(other) => other is FileOfInterest && entity.path == other.entity.path;

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