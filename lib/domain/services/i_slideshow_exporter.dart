enum SlideshowTransition { fade, flip, spiral }

enum SlideshowQuality {
  small,  // 640×360  — fastest
  medium, // 854×480  — balanced
  large;  // 1280×720 — highest quality

  int get width  => switch (this) { small => 640,  medium => 854,  large => 1280 };
  int get height => switch (this) { small => 360,  medium => 480,  large => 720  };
  String get label => switch (this) {
    small  => 'Small (640×360)',
    medium => 'Medium (854×480)',
    large  => 'Large (1280×720)',
  };
}

abstract class ISlideshowExporter {
  /// True when this exporter can run on the current system.
  bool get isAvailable;

  /// Human-readable reason [isAvailable] is false. Empty when available.
  String get unavailableReason;

  /// Export a slideshow as an MP4 to [outputPath].
  ///
  /// [imagePaths]        — ordered image file paths.
  /// [audioPath]         — optional audio track; null = silent video.
  /// [outputPath]        — destination .mp4 file path.
  /// [frameDelaySeconds] — how long each image is shown (full opacity).
  /// [transitions]       — set of enabled transition styles; empty = hard cut.
  ///                       One is chosen at random for each image pair.
  /// [onProgress]        — called with (current, total) as each image is added.
  Future<void> export({
    required List<String> imagePaths,
    required String? audioPath,
    required String outputPath,
    required int frameDelaySeconds,
    required Set<SlideshowTransition> transitions,
    required SlideshowQuality quality,
    void Function(int current, int total)? onProgress,
  });
}

class SlideshowExportException implements Exception {
  final String message;
  const SlideshowExportException(this.message);
  @override
  String toString() => message;
}
