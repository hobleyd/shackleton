import '../models/tag.dart';

abstract class TagHandler {
  void removeTag(Tag tag);
  void updateTags(String tags);
}