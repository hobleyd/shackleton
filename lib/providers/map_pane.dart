import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/map_settings.dart';
import '../models/preview_settings.dart';

part 'map_pane.g.dart';

@riverpod
class MapPane extends _$MapPane {
  @override
  MapSettings build() {
    return const MapSettings();
  }

  void changeWidth(double delta) {
    state = state.copyWith(width: state.width - delta);
  }

  void setVisibility(bool isVisible) {
    state = state.copyWith(visible: isVisible);
  }
}
