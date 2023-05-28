import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/preview.dart';

part 'preview_notifier.g.dart';

@riverpod
class PreviewNotifier extends _$PreviewNotifier {
  @override
  Preview build() {
    return const Preview();
  }

  void changeHeight(double delta) {
    state = state.copyWith(height: state.height + delta);
  }

  void setVisibility(bool isVisible) {
    state = state.copyWith(visible: isVisible);
  }
}
