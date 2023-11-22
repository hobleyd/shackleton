import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/tag.dart';
import 'selected_entities.dart';
import 'selected_metadata.dart';

part 'selected_tags.g.dart';

@riverpod
class SelectedTags extends _$SelectedTags {
  @override
  List<Tag> build(FileType selectionType, FileType backupSelectionType) {
    List<FileMetaData> metadata = ref.watch(selectedMetadataProvider(selectionType, backupSelectionType));

    List<Tag> tags = [...{ for (var e in metadata) ...e.tags}];
    tags.sort();

    return tags;
  }
}