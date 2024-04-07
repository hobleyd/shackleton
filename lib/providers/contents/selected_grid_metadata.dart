import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/providers/contents/grid_contents.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../metadata.dart';
import 'selected_grid_entities.dart';

part 'selected_metadata.g.dart';

@riverpod
class SelectedMetadata extends _$SelectedMetadata {
  @override
  List<FileMetaData> build() {
    List<FileOfInterest> selectedEntities = ref.watch(selectedGridEntitiesProvider);
    List<FileOfInterest> gridEntities = ref.watch(gridContentsProvider);

    return _getMetaData(selectedEntities.isNotEmpty ? selectedEntities : gridEntities);
  }

  List<FileMetaData> _getMetaData(List<FileOfInterest> entities) {
    List<FileMetaData> metadata = entities.map((e) => ref.watch(metadataProvider(e))).toList();
    metadata.sort();

    return metadata;
  }
}