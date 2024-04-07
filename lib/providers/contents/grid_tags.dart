import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';

import 'grid_contents.dart';
import 'selected_grid_entities.dart';

part 'grid_tags.g.dart';

@riverpod
class GridTags extends _$GridTags {
  @override
  List<Tag> build() {
    List<FileOfInterest> selectedEntities = ref.watch(selectedGridEntitiesProvider);
    List<FileOfInterest> gridEntities = ref.watch(gridContentsProvider);

    List<FileOfInterest> entities = selectedEntities.isNotEmpty ? selectedEntities : gridEntities;

    List<FileMetaData> metadata = entities.map((e) => ref.watch(metadataProvider(e))).toList();
    List<Tag> tags = [...{ for (var e in metadata) ...e.tags}];
    tags.sort();
    return tags;
  }
}