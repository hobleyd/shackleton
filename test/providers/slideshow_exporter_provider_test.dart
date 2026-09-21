import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shackleton/providers/slideshow_exporter_provider.dart';
import 'package:shackleton/services/avfoundation_slideshow_exporter.dart';
import 'package:shackleton/services/ffmpeg_slideshow_exporter.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() {
    container.dispose();
  });

  test('selects the exporter for the current platform', () {
    final exporter = container.read(slideshowExporterProvider);

    if (Platform.isMacOS) {
      expect(exporter, isA<AvFoundationSlideshowExporter>());
    } else {
      expect(exporter, isA<FfmpegSlideshowExporter>());
    }
  });
}
