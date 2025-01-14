import 'dart:io';
import 'dart:math';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';

import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';

extension StringFuncs on String {
  String trimCharLeft(String pattern) {
    if (isEmpty || pattern.isEmpty || pattern.length > length) return this;
    var tmp = this;
    while (tmp.startsWith(pattern)) {
      tmp = substring(pattern.length);
    }
    return tmp;
  }

  String trimCharRight(String pattern) {
    if (isEmpty || pattern.isEmpty || pattern.length > length) return this;
    var tmp = this;
    while (tmp.endsWith(pattern)) {
      tmp = substring(0, length - pattern.length);
    }
    return tmp;
  }

  String trimChar(String pattern) {
    return trimCharLeft(pattern).trimCharRight(pattern);
  }
}

Future<FileOfInterest?> createZip(FileOfInterest folder, Set<FileOfInterest> filesToZip) async {
  if (filesToZip.isEmpty) {
    return null;
  }

  FileOfInterest foi = FileOfInterest(entity: getZipName(folder, filesToZip));
  var encoder = ZipFileEncoder();
  encoder.create(foi.path, level: DeflateLevel.bestCompression);
  for (var file in filesToZip) {
    if (file.isDirectory) {
      encoder.addDirectory(file.entity as Directory, includeDirName: true);
    }
    else if (file.isFile) {
      encoder.addFile(file.entity as File);
    }
  }
  encoder.close();
  return foi;
}

String convertLatLng(double decimal, bool isLat) {
  String degree = "${decimal.abs().toString().split(".")[0]} deg";

  double minutesBeforeConversion = double.parse("0.${decimal.toString().split(".")[1]}");
  String minutes = "${(minutesBeforeConversion * 60).toString().split('.')[0]}'";

  double secondsBeforeConversion = double.parse("0.${(minutesBeforeConversion * 60).toString().split('.')[1]}");
  String seconds = '${double.parse((secondsBeforeConversion * 60).toString()).toStringAsFixed(2)}"';

  return "$degree $minutes $seconds ${isLat ? decimal > 0 ? 'N' : 'S' : decimal > 0 ? 'E' : 'W'}";
}

FileSystemEntity getEntity(String path) {
  var entity = switch (FileSystemEntity.typeSync(path)) {
    FileSystemEntityType.directory => Directory(path),
    FileSystemEntityType.link => Link(path),
    _  => File(path),
  };

  return entity;
}

String getLocation(FileMetaData? metadata, bool latitude) {
  double loc = 0.0;
  if (metadata != null) {
    if (metadata.gpsLocation != null) {
      loc = latitude ? metadata.gpsLocation!.latitude : metadata.gpsLocation!.longitude;
    }
  }

  return loc == 0.0 ? '' : convertLatLng(loc, latitude);
}

String getSizeString(int size, { int decimals = 0 }) {
  const suffixes = ["b", "k", "m", "g", "t"];
  if (size == 0) {
    return '0${suffixes[0]}';
  }

  var i = (log(size) / log(1024)).floor();
  return ((size / pow(1024, i)).toStringAsFixed(decimals)) + suffixes[i];
}

String getEntitySizeString({required FileOfInterest entity, int decimals = 0}) {
  return getSizeString(entity.stat.size, decimals: decimals);
}

String getHomeFolder() {
  return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
}

File getZipName(FileOfInterest folder, Set<FileOfInterest> filesToZip) {
  if (filesToZip.length == 1) {
    String name = filesToZip.first.path;
    if (name.contains('.')) {
      name = name.replaceRange(name.lastIndexOf('.'), null, '.zip');
    } else {
      name += '.zip';
    }

    return File(join(folder.path, name));
  }

  // Multiple files.
  String prefix = 'Archive';
  File output = File(join(folder.path, '$prefix.zip'));
  int version = 1;
  while (output.existsSync()) {
    output = File(join(folder.path, '$prefix-${version++}.zip'));
  }

  return output;
}

