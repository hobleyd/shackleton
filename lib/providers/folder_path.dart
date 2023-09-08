import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../misc/utils.dart';

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
    if (state.contains(newPath)) {
      // Don't trigger a rebuild if the folder is already visible.
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

  void setFolder(Directory dir) {
    state = [ dir ];
  }
}
