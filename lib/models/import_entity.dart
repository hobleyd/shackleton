import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:process_run/process_run.dart';

import '../misc/utils.dart';
import 'file_of_interest.dart';

class ImportEntity {
  FileOfInterest fileToImport;
  String error = "";
  String renamedFile = "";
  bool willImport = false;
  bool hasConflict = false;

  @override
  bool operator ==(other) => other is ImportEntity && fileToImport.path == other.fileToImport.path;

  ImportEntity({ required this.fileToImport, String? renamedFile, bool? willImport, bool? hasConflict, String? error}) {
    this.willImport = willImport ?? fileToImport.shouldImport;
    this.renamedFile = renamedFile ?? "";
    this.hasConflict = hasConflict ?? false;
    this.error       = error ?? "";
  }

  ImportEntity copyWith({FileOfInterest? fileToImport, String? renamedFile, bool? willImport, bool? hasConflict, String? error}) {
    return ImportEntity(
      fileToImport: fileToImport ?? this.fileToImport,
      renamedFile: renamedFile ?? this.renamedFile,
      willImport: willImport ?? this.willImport,
      hasConflict: hasConflict ?? this.hasConflict,
      error: error ?? this.error,
    );
  }

  Future<void> getPathInLibrary() async {
    renamedFile = "";

    if (willImport && fileToImport.exists) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-CreateDate', fileToImport.path]);
        DateTime creationDateTime;
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          // Create Date: 2016:06:26 14:46:58
          creationDateTime = DateFormat("yyyy:MM:dd HH:mm:ss").parse(output.stdout);
        } else {
          creationDateTime = DateTime.now();
        }
        String year = DateFormat('yyyy').format(creationDateTime);
        String month = DateFormat('MM - MMMM').format(creationDateTime);
        renamedFile = join(getHomeFolder(), 'Pictures', year, month, fileToImport.name);
        await validateEntityName();
      }
    } else {
      willImport = false;
      hasConflict = true;
    }
  }

  Future<void> validateEntityName() async {
    FileSystemEntity? dest = getEntity(renamedFile);
    if (dest != null) {
      hasConflict = dest.existsSync() && await fileToImport.different(FileOfInterest(entity: dest));
      willImport = false;
    } else {
      hasConflict = false;
    }
  }

  @override
  String toString() {
    return 'path: $fileToImport with import flag $willImport, and error $error';
  }
}