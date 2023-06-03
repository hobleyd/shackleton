import 'dart:io';

import 'package:flutter/foundation.dart';

@immutable
class FolderUISettings {
  final FileSystemEntity entity;
  final bool isDropZone;
  final double width;

  const FolderUISettings({
    required this.entity,
    this.isDropZone = false,
    this.width = 200,
  });

  FolderUISettings copyWith({double? width, bool? isDropZone}) {
    return FolderUISettings(
      entity: entity,
      width: width ?? this.width,
      isDropZone: isDropZone ?? this.isDropZone,
    );
  }

  static FolderUISettings fromMap(Map<String, dynamic> setting) {
    FolderUISettings result =  FolderUISettings(
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

  @override
  String toString() {
    return '${entity.path} with width of $width, and isDropZone is $isDropZone';
  }
}