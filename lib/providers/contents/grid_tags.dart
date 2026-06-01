import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';
import '../../repositories/file_tags_repository.dart';
import 'grid_contents.dart';
import 'selected_grid_entities.dart';

part 'grid_tags.g.dart';

@riverpod
class GridTags extends _$GridTags {
  @override
  List<Tag> build() {
    final selectedEntities = ref.watch(selectedGridEntitiesProvider);

    if (selectedEntities.isNotEmpty) {
      // Small, explicit selection: read from already-loaded metadataProviders.
      final metadata = selectedEntities.map((e) => ref.watch(metadataProvider(e))).toList();
      final tags = [...{for (var e in metadata) ...e.tags}];
      tags.sort();
      return tags;
    }

    // Nothing selected: batch-load the union of tags for all grid items via
    // a small number of DB queries rather than one provider per file.
    final gridEntities = ref.watch(gridContentsProvider);
    final repo = ref.read(fileTagsRepositoryProvider.notifier);
    _loadTagsForGrid(repo, gridEntities);
    return [];
  }

  Future<void> _loadTagsForGrid(
      FileTagsRepository repo, List<FileOfInterest> entities) async {
    if (entities.isEmpty) return;
    final tags = await repo.getTagsForPaths([for (final e in entities) e.path as String]);
    if (ref.mounted) state = tags;
  }
}