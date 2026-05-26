class ExifToolMissingException implements Exception {
  const ExifToolMissingException();
}

class MetadataWriteException implements Exception {
  final String fileName;
  const MetadataWriteException(this.fileName);
}
