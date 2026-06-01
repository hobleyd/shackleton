import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../metadata.dart';
import 'selected_grid_entities.dart';

part 'selected_grid_metadata.g.dart';

@riverpod
class SelectedGridMetadata extends _$SelectedGridMetadata {
  @override
  List<FileMetaData> build() {
    List<FileOfInterest> selectedEntities = ref.watch(selectedGridEntitiesProvider);
    if (selectedEntities.isEmpty) return [];

    return _getMetaData(selectedEntities);
  }

  List<FileMetaData> _getMetaData(List<FileOfInterest> entities) {
    List<FileMetaData> metadata = entities.map((e) => ref.watch(metadataProvider(e))).toList();
    metadata.sort();

    return metadata;
  }
}