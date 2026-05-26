import 'file_of_interest.dart';

class ImportEntity {
  FileOfInterest fileToImport;
  String error = "";
  String renamedFile = "";
  bool willImport = false;
  bool hasConflict = false;

  @override
  get hashCode => fileToImport.path.hashCode;

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

  @override
  String toString() {
    return 'path: $fileToImport with import flag $willImport, and error $error';
  }
}
