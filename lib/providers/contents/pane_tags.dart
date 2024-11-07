import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';

part 'pane_tags.g.dart';

@Riverpod(keepAlive: true)
class PaneTags extends _$PaneTags {
  @override
  List<Tag> build() {
    return [];
  }

  void replace(FileOfInterest entity) {
    FileMetaData metadata = ref.read(metadataProvider(entity));
    metadata.tags.sort();
    state = metadata.tags;
  }
}