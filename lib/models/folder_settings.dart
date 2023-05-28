import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
class FolderSettings {
  final FileSystemEntity entity;
  final bool isDropZone;
  final double width;

  const FolderSettings({
    required this.entity,
    this.isDropZone = false,
    this.width = 200,
  });

  FolderSettings copyWith({double? width, bool? isDropZone}) {
    return FolderSettings(
      entity: entity,
      width: width ?? this.width,
      isDropZone: isDropZone ?? this.isDropZone,
    );
  }

  static FolderSettings fromMap(Map<String, dynamic> setting) {
    FolderSettings result =  FolderSettings(
      entity: FileSystemEntity.typeSync(setting['path']) == FileSystemEntityType.file ? File(setting['path]']) : Directory(setting['path']),
      width: setting['width'],
    );

    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'path': entity.path,
      'width': width,
    };
  }

  String toString() {
    return '${entity.path} with width of $width, and isDropZone is $isDropZone';
  }
}