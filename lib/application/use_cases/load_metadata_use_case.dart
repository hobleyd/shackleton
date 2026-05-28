import '../../domain/repositories/i_file_tags_repository.dart';
import '../../domain/services/i_exif_tool_service.dart';
import '../../models/entity.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';

class LoadMetadataUseCase {
  final IExifToolService _exifService;
  final IFileTagsRepository _tagsRepository;

  LoadMetadataUseCase({
    required IExifToolService exifService,
    required IFileTagsRepository tagsRepository,
  })  : _exifService = exifService,
        _tagsRepository = tagsRepository;

  /// Returns cached metadata directly from the DB without touching the file.
  /// Returns null when [entity] does not support metadata or is not yet indexed.
  Future<FileMetaData?> fetchFromDb(FileOfInterest entity) async {
    if (!entity.isMetadataSupported) return null;
    return _tagsRepository.getMetadataForFile(entity.path, entity);
  }

  /// Reads tags and GPS from [entity] and persists them to the tags DB.
  /// Returns null when [entity] does not support metadata.
  Future<FileMetaData?> execute(FileOfInterest entity) async {
    if (!entity.isMetadataSupported) return null;

    final result = await _exifService.readTagsAndLocation(entity.path);
    final metadata = FileMetaData(entity: entity, tags: result.tags, gpsLocation: result.location);
    await _tagsRepository.writeTags(Entity(path: entity.path, metadata: metadata));
    return metadata;
  }
}
