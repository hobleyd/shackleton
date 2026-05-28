import '../../models/entity.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';

abstract class IFileTagsRepository {
  Future<List<Tag>> getTags();
  Future<List<FileOfInterest>> getFilesForTag(Tag tag);

  /// Returns cached metadata (tags + GPS) for [path] when the file is
  /// already indexed in the DB, or null if the file has never been seen.
  Future<FileMetaData?> getMetadataForFile(String path, FileOfInterest entity);

  Future<void> writeTags(Entity entity);
  Future<void> addTagToFile(String filePath, String tagName);
  Future<void> removeTagsForEntity(Entity entity, {bool deleteEntity = true});
  Future<bool> cleanOrphanedTags();
}
