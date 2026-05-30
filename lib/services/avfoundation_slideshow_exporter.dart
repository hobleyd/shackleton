import 'dart:async';

import 'package:flutter/services.dart';

import '../domain/services/i_slideshow_exporter.dart';

/// Routes slideshow export to the native Swift AVFoundation implementation
/// via a Flutter MethodChannel.  macOS only.
class AvFoundationSlideshowExporter implements ISlideshowExporter {
  static const _channel         = MethodChannel('com.shackleton/slideshow');
  static const _progressChannel = EventChannel('com.shackleton/slideshow_progress');

  @override
  bool get isAvailable => true;

  @override
  String get unavailableReason => '';

  @override
  Future<void> export({
    required List<String> imagePaths,
    required String? audioPath,
    required String outputPath,
    required int frameDelaySeconds,
    required double transitionDurationSeconds,
    required Set<SlideshowTransition> transitions,
    required SlideshowQuality quality,
    void Function(int current, int total)? onProgress,
  }) async {
    StreamSubscription<dynamic>? sub;
    if (onProgress != null) {
      sub = _progressChannel.receiveBroadcastStream().listen((event) {
        final map = Map<String, dynamic>.from(event as Map);
        onProgress(map['current'] as int, map['total'] as int);
      });
    }
    try {
      await _channel.invokeMethod<void>('createSlideshow', {
        'imagePaths': imagePaths,
        'audioPath': audioPath,
        'outputPath': outputPath,
        'frameDelaySeconds': frameDelaySeconds,
        'transitionDurationSeconds': transitionDurationSeconds,
        'transitions': transitions.map((t) => t.name).toList(),
        'outputWidth':  quality.width,
        'outputHeight': quality.height,
      });
    } on PlatformException catch (e) {
      throw SlideshowExportException(e.message ?? 'AVFoundation export failed');
    } finally {
      await sub?.cancel();
    }
  }
}
