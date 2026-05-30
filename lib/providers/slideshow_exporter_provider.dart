import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/services/i_slideshow_exporter.dart';
import '../services/avfoundation_slideshow_exporter.dart';
import '../services/ffmpeg_slideshow_exporter.dart';

part 'slideshow_exporter_provider.g.dart';

/// Selects the appropriate [ISlideshowExporter] for the current platform.
///
/// macOS  → AvFoundationSlideshowExporter  (native, no external tools)
/// Linux  → FfmpegSlideshowExporter        (requires FFmpeg on PATH)
/// Windows→ FfmpegSlideshowExporter        (requires FFmpeg on PATH;
///           swap for a WindowsMediaFoundationSlideshowExporter when ready)
@Riverpod(keepAlive: true)
ISlideshowExporter slideshowExporter(Ref ref) {
  if (Platform.isMacOS) return AvFoundationSlideshowExporter();
  return FfmpegSlideshowExporter();
}
