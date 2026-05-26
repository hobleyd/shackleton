import '../../models/entity.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';

abstract class IFileTagsRepository {
  Future<List<Tag>> getTags();
  Future<List<FileOfInterest>> getFilesForTag(Tag tag);
  Future<void> writeTags(Entity entity);
  Future<void> removeTagsForEntity(Entity entity, {bool deleteEntity = true});
  Future<bool> cleanOrphanedTags();
}
