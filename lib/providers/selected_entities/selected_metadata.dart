import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../metadata.dart';
import 'selected_entities.dart';

part 'selected_metadata.g.dart';

@riverpod
class SelectedMetadata extends _$SelectedMetadata {
  @override
  List<FileMetaData> build(FileType selectionType, FileType backupSelectionType) {
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesProvider(selectionType));
    if (entities.isEmpty) {
      entities = ref.watch(selectedEntitiesProvider(backupSelectionType));
    }

    List<FileMetaData> metadata = entities.map((e) => ref.watch(metadataProvider(e))).toList();
    metadata.sort();

    return metadata;
  }
}