import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/file_of_interest.dart';

part 'selected_pane_entity.g.dart';

@riverpod
class SelectedPaneEntity extends _$SelectedPaneEntity {
  @override
  FileOfInterest? build() {
    return null;
  }

  void replace(FileOfInterest entity) {
    state = entity;
  }
}