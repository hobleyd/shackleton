import '../../domain/repositories/i_file_tags_repository.dart';
import '../../models/entity.dart';
import '../../models/file_of_interest.dart';

class DeleteFilesUseCase {
  final IFileTagsRepository _tagsRepository;

  DeleteFilesUseCase({required IFileTagsRepository tagsRepository})
      : _tagsRepository = tagsRepository;

  /// Deletes [entity] from the filesystem (via trash/recycle where available)
  /// and removes its tags from the database.
  ///
  /// The filesystem move-to-trash is fire-and-forget; the DB cleanup is
  /// awaited so callers can be confident the record is gone.
  Future<void> execute(FileOfInterest entity) async {
    if (entity.exists) entity.delete();
    await _tagsRepository.removeTagsForEntity(Entity(path: entity.path));
  }
}
