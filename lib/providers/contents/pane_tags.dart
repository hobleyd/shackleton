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
    // metadataProvider is deliberately conditionally-alive (auto-disposed for
    // off-screen items); this is a one-off read, not a ref.watch subscription,
    // so it doesn't force it to stay alive the way PaneTags itself is.
    // ignore: riverpod_lint/only_use_keep_alive_inside_keep_alive
    FileMetaData metadata = ref.read(metadataProvider(entity));
    List<Tag> tags = List.from(metadata.tags);
    tags.sort();
    state = tags;
  }
}