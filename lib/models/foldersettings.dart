class FolderSettings {
  String path;
  bool isDropZone = false;
  double width = 200;

  FolderSettings({
    required this.path,
    this.isDropZone = false,
    this.width = 200,
  });

  static FolderSettings fromMap(Map<String, dynamic> setting) {
    FolderSettings result =  FolderSettings(
      path: setting['path'],
      width: setting['width'],
    );

    return result;
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'width': width,
    };
  }
}