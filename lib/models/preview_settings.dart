import 'package:flutter/foundation.dart';

@immutable
class PreviewSettings {
  final bool visible;
  final double height;

  const PreviewSettings({
    this.visible = false,
    this.height = 320,
  });

  PreviewSettings copyWith({double? height, bool? visible}) {
    return PreviewSettings(
      height: height ?? this.height,
      visible: visible ?? this.visible,
    );
  }

  @override
  String toString() {
    return 'Preview visibility is $visible with height of $height';
  }
}