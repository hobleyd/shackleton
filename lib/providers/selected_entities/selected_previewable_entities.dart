import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_of_interest.dart';
import 'selected_entities.dart';

part 'selected_previewable_entities.g.dart';

@riverpod
class SelectedPreviewableEntities extends _$SelectedPreviewableEntities {
  @override
  List<FileOfInterest> build(FileType selectionType) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(selectionType));
    List<FileOfInterest> previewable = selectedEntities.where((element) => element.canPreview).toList();
    previewable.sort();
    return previewable;
  }
}