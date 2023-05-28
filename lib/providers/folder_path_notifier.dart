import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'folder_path_notifier.g.dart';

@riverpod
class FolderPathNotifier extends _$FolderPathNotifier {
  @override
  List<Directory> build() {
    return [ _getHome() ];
  }

  Directory _getHome() {
    return Directory(Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!);
  }

  void addFolder(Directory clickedPath, Directory newPath) {
    if (clickedPath == state.last) {
      state = [ ...state, newPath];
    } else {
      state = [
        ...state.sublist(0, state.indexOf(clickedPath) + 1),
        newPath,
      ];
    }
  }
}
