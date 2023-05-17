import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/foldersettings.dart';

extension MapUtils<K, V> on Map<K, V> {
  Map<K, V> where(bool Function(K, V) condition) {
    Map<K, V> result = {};
    entries.forEach((element) {
      if (condition(element.key, element.value)) {
        result[element.key] = element.value;
      }
    });
    return result;
  }
}

class Folder extends ChangeNotifier {
  bool showHiddenFiles = false;
  bool showPreview = false;
  double previewHeight = 200;
  Map<Directory, List<FileSystemEntity>> entities = {};
  Set<FileSystemEntity> selectedEntities = {};
  Map<Directory, FolderSettings> folderSettings = {};
  List<Directory> folderPaths = [];

  void addFolder(Directory clickedPath, Directory newPath) {
    if (folderPaths.length > 1) {
      if (clickedPath != folderPaths.last) {
        int index = folderPaths.indexOf(clickedPath) + 1;
        if (folderPaths.length >= index) {
          folderPaths.removeRange(index, folderPaths.length);
        }
      }
    }

    folderPaths.add(newPath);
    notifyListeners();
  }

  void addSelection(FileSystemEntity entity) {
    selectedEntities.add(entity);
    notifyListeners();
  }

  void getFolderContents(Directory path) {
    if (!entities.containsKey(path)) {
      entities[path] = path.listSync().toList();
    }

    if (!showHiddenFiles) {
      entities[path]!.removeWhere((item) =>
          item.path
              .split('/')
              .last
              .startsWith('.'));
    }
    entities[path]!.sort((a, b) => a.path.split('/').last.compareTo(b.path.split('/').last));
  }

  FolderSettings getSettings(Directory d) {
    if (!folderSettings.containsKey(d)) {
      folderSettings[d] = FolderSettings(path: d.path);
    }

    return folderSettings[d]!;
  }

  void refreshFolder(Directory d) {
    entities.remove(d);
    getFolderContents(d);

    notifyListeners();
  }

  void removeSelection(FileSystemEntity entity) {
    selectedEntities.remove(entity);
    notifyListeners();
  }

  void setDropZone(Directory d, bool state) {
    getSettings(d).isDropZone = state;
    notifyListeners();
  }

  void setFolderWidth(Directory d, double delta) {
    getSettings(d).width += delta;
    notifyListeners();
  }

  void setPreviewHeight(double delta) {
    previewHeight += delta;
    notifyListeners();
  }

  void setStartingFolder(Directory path) {
    folderPaths.clear();
    folderPaths.add(path);
  }

  void togglePreview() {
    showPreview = !showPreview;

    notifyListeners();
  }
}