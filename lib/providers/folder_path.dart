import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';

part 'folder_path.g.dart';

@riverpod
class FolderPath extends _$FolderPath {
  @override
  List<Directory> build() {
    return [ _getHome() ];
  }

  Directory _getHome() {
    return Directory(getHomeFolder());
  }

  void addFolder(Directory clickedPath, Directory newPath) {
    // Don't trigger a rebuild if the folder is already visible.
    if (state.contains(newPath)) {
      return;
    }

    if (clickedPath == state.last) {
      state = [ ...state, newPath];
    } else {
      state = [
        ...state.sublist(0, state.indexOf(clickedPath) + 1),
        newPath,
      ];
    }
  }

  bool contains(FileOfInterest folder) {
    try {
      state.firstWhere((element) => element.path == folder.path);
      return true;
    } on StateError catch (_) {
      return false;
    }
  }

  void removeFolder(FileOfInterest folder) {
    if (contains(folder)) {
      state = [
        ...state.sublist(0, state.indexWhere((element) => element.path == folder.path))
      ];
    }
  }

  void setFolder(Directory dir) {
    state = [ dir ];
  }
}
