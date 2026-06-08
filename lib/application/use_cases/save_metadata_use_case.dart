import '../../application/exceptions.dart' show MetadataWriteException;
import '../../domain/repositories/i_file_tags_repository.dart';
import '../../domain/services/i_exif_tool_service.dart';
import '../../models/entity.dart';
import '../../models/file_metadata.dart';

class SaveMetadataUseCase {
  final IExifToolService _exifService;
  final IFileTagsRepository _tagsRepository;

  SaveMetadataUseCase({
    required IExifToolService exifService,
    required IFileTagsRepository tagsRepository,
  })  : _exifService = exifService,
        _tagsRepository = tagsRepository;

  /// Persists [metadata] to the tags DB and, when [updateFile] is true, writes
  /// tags and GPS back to the file via the metadata service.
  ///
  /// Returns updated [FileMetaData] on success.
  /// Throws [MetadataWriteException] when the file write fails.
  Future<FileMetaData> execute(FileMetaData metadata, {bool updateFile = false}) async {
    await _tagsRepository.writeTags(Entity(path: metadata.entity!.path, metadata: metadata));

    if (!updateFile) return metadata;
    if (!metadata.entity!.isMetadataSupported) return metadata;

    final location = metadata.entity!.isLocationSupported ? metadata.gpsLocation : null;
    final success = await _exifService.writeTags(metadata.entity!.path, metadata.tags, location: location);

    if (success) return metadata.copyWith(corruptedMetadata: false);
    throw MetadataWriteException(metadata.entity!.name);
  }
}
