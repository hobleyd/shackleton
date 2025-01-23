import 'package:flutter/foundation.dart';

@immutable
class PreviewSettings {
  final double height;

  const PreviewSettings({
    this.height = 320,
  });

  PreviewSettings copyWith({double? height}) {
    return PreviewSettings(
      height: height ?? this.height,
    );
  }

  @override
  String toString() {
    return 'Preview has a height of $height';
  }
}