import 'package:flutter/foundation.dart';

@immutable
class MapSettings {
  final bool visible;
  final double width;

  const MapSettings({
    this.visible = false,
    this.width = 400,
  });

  MapSettings copyWith({double? width, bool? visible}) {
    return MapSettings(
      width: width ?? this.width,
      visible: visible ?? this.visible,
    );
  }

  @override
  String toString() {
    return 'Preview visibility is $visible with height of $width';
  }
}