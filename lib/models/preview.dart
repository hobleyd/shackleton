import 'package:flutter/foundation.dart';

@immutable
class Preview {
  final bool visible;
  final double height;

  const Preview({
    this.visible = false,
    this.height = 320,
  });

  Preview copyWith({double? height, bool? visible}) {
    return Preview(
      height: height ?? this.height,
      visible: visible ?? this.visible,
    );
  }

  @override
  String toString() {
    return 'Preview visibility is $visible with height of $height';
  }
}