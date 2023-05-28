import 'dart:io';

class FolderPaths {
  List<Directory> folderPaths = [];

  FolderPaths() {
    folderPaths.add(Directory(_getHome()));
  }

  String _getHome() {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  }

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
  }
}
