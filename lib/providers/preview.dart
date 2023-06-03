import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/preview_settings.dart';

part 'preview.g.dart';

@riverpod
class Preview extends _$Preview {
  @override
  PreviewSettings build() {
    return const PreviewSettings();
  }

  void changeHeight(double delta) {
    state = state.copyWith(height: state.height + delta);
  }

  void setVisibility(bool isVisible) {
    state = state.copyWith(visible: isVisible);
  }
}
