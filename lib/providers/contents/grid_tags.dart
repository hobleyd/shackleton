import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/selected_entities/selected_grid_entities.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../providers/metadata.dart';
import '../../models/tag.dart';

part 'selected_tags.g.dart';

@riverpod
class SelectedTags extends _$SelectedTags {
  @override
  List<Tag> build() {
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesProvider);
    List<FileMetaData> metadata = entities.map((e) => ref.watch(metadataProvider(e))).toList();
    List<Tag> tags = [...{ for (var e in metadata) ...e.tags}];
    tags.sort();
    return tags;
  }
}