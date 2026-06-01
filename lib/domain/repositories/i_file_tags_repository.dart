import '../../models/entity.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';

abstract class IFileTagsRepository {
  Future<List<Tag>> getTags();
  Future<List<FileOfInterest>> getFilesForTag(Tag tag);

  /// Returns the union of all tags on the given files in a small number of
  /// batched DB queries — much cheaper than watching a metadataProvider per file.
  Future<List<Tag>> getTagsForPaths(List<String> paths);

  /// Bulk-loads metadata for every file that has [tag] into an in-memory
  /// cache. Subsequent [getMetadataForFile] calls for those files consume
  /// from the cache instead of issuing individual DB queries.
  Future<void> prefetchMetadataForTag(Tag tag);

  /// Returns cached metadata (tags + GPS) for [path] when the file is
  /// already indexed in the DB, or null if the file has never been seen.
  Future<FileMetaData?> getMetadataForFile(String path, FileOfInterest entity);

  Future<void> writeTags(Entity entity);
  Future<void> addTagToFile(String filePath, String tagName);
  Future<void> removeTagsForEntity(Entity entity, {bool deleteEntity = true});
  Future<bool> cleanOrphanedTags();
}
