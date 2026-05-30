import 'dart:io';
import 'dart:math';

import 'package:process_run/process_run.dart';

import '../domain/services/i_slideshow_exporter.dart';

const _fps = 30;

// Maps each SlideshowTransition to its FFmpeg xfade transition name.
const _ffmpegNames = {
  SlideshowTransition.fade:   'fade',
  SlideshowTransition.flip:   'squeezeh',  // horizontal squeeze — simulates a card flip
  SlideshowTransition.spiral: 'radial',    // clock-sweep radial wipe
};

class FfmpegSlideshowExporter implements ISlideshowExporter {
  String? _ffmpegBin;
  bool _checked = false;

  // ── availability ──────────────────────────────────────────────────────────

  @override
  bool get isAvailable {
    if (!_checked) _detect();
    return _ffmpegBin != null;
  }

  @override
  String get unavailableReason {
    if (!_checked) _detect();
    return _ffmpegBin != null
        ? ''
        : 'FFmpeg not found. Install it (e.g. "brew install ffmpeg") and restart the app.';
  }

  void _detect() {
    _checked = true;
    _ffmpegBin = whichSync('ffmpeg');
    if (_ffmpegBin != null) return;

    // Homebrew ARM macOS
    if (File('/opt/homebrew/bin/ffmpeg').existsSync()) {
      _ffmpegBin = '/opt/homebrew/bin/ffmpeg';
      return;
    }
    // Homebrew Intel macOS
    if (File('/usr/local/bin/ffmpeg').existsSync()) {
      _ffmpegBin = '/usr/local/bin/ffmpeg';
    }
  }

  // ── export ────────────────────────────────────────────────────────────────

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
    if (!isAvailable) throw SlideshowExportException(unavailableReason);
    if (imagePaths.isEmpty) throw const SlideshowExportException('No images provided');

    // Remove existing output so FFmpeg doesn't prompt.
    final out = File(outputPath);
    if (out.existsSync()) out.deleteSync();

    final tmpDir = Directory.systemTemp.createTempSync('shackleton_slideshow_');
    try {
      final useTransitions = transitions.isNotEmpty && imagePaths.length > 1;
      final args = useTransitions
          ? _xfadeArgs(imagePaths, audioPath, outputPath, frameDelaySeconds, transitionDurationSeconds, transitions, quality)
          : await _concatArgs(imagePaths, audioPath, outputPath, frameDelaySeconds, tmpDir, quality);

      final result = await Process.run(_ffmpegBin!, args);
      if (result.exitCode != 0) {
        throw SlideshowExportException(
            'FFmpeg failed (exit ${result.exitCode}):\n${result.stderr}');
      }
    } finally {
      tmpDir.deleteSync(recursive: true);
    }
  }

  // ── concat-demuxer (no transitions) ──────────────────────────────────────

  Future<List<String>> _concatArgs(
    List<String> imagePaths,
    String? audioPath,
    String outputPath,
    int frameDelaySec,
    Directory tmpDir,
    SlideshowQuality quality,
  ) async {
    final concatFile = File('${tmpDir.path}/concat.txt');
    final buf = StringBuffer();
    for (final path in imagePaths) {
      buf.writeln("file '${path.replaceAll("'", "'\\''")}'");
      buf.writeln('duration $frameDelaySec');
    }
    // FFmpeg needs the last entry repeated so the final image shows at full duration.
    buf.writeln("file '${imagePaths.last.replaceAll("'", "'\\''")}'");
    concatFile.writeAsStringSync(buf.toString());

    final args = <String>[
      '-f', 'concat', '-safe', '0', '-i', concatFile.path,
    ];
    if (audioPath != null) args.addAll(['-i', audioPath]);
    args.addAll([
      '-vf', _scaleFilter(quality),
      '-c:v', 'libx264', '-pix_fmt', 'yuv420p',
    ]);
    if (audioPath != null) {
      args.addAll(['-map', '0:v', '-map', '1:a', '-c:a', 'aac', '-b:a', '128k', '-shortest']);
    }
    args.addAll(['-y', outputPath]);
    return args;
  }

  // ── xfade (transitions) ───────────────────────────────────────────────────

  List<String> _xfadeArgs(
    List<String> imagePaths,
    String? audioPath,
    String outputPath,
    int frameDelaySec,
    double transitionDurationSec,
    Set<SlideshowTransition> transitions,
    SlideshowQuality quality,
  ) {
    final N = imagePaths.length;
    final F = frameDelaySec.toDouble();
    // Clamp so the transition never exceeds the per-image hold time.
    final D = transitionDurationSec.clamp(0.1, F - 0.1);
    final rng = Random();
    final transitionList = transitions.toList();

    final args = <String>[];

    // Individual looped image inputs; give non-last images extra time for the
    // transition overlap.
    for (int i = 0; i < N; i++) {
      final t = i < N - 1 ? (F + D) : F;
      args.addAll(['-loop', '1', '-t', '$t', '-i', imagePaths[i]]);
    }
    if (audioPath != null) args.addAll(['-i', audioPath]);

    // filter_complex: scale each input, then chain xfade filters with a
    // randomly chosen transition for each image pair.
    final filter = StringBuffer();
    for (int i = 0; i < N; i++) {
      filter.write('[$i:v]${_scaleFilter(quality)},fps=$_fps[v$i];');
    }

    String prev = 'v0';
    double accOffset = 0;
    for (int i = 1; i < N; i++) {
      accOffset = accOffset + F - (i > 1 ? D : 0);
      final label = i < N - 1 ? 't$i' : 'vout';
      final transName = _ffmpegNames[transitionList[rng.nextInt(transitionList.length)]]!;
      filter.write('[$prev][v$i]xfade=transition=$transName'
          ':duration=${D.toStringAsFixed(3)}'
          ':offset=${accOffset.toStringAsFixed(3)}[$label];');
      prev = label;
      if (i == 1) accOffset = F;
    }

    final filterStr = filter.toString();
    final filterClean = filterStr.endsWith(';')
        ? filterStr.substring(0, filterStr.length - 1)
        : filterStr;
    args.addAll(['-filter_complex', filterClean]);
    args.addAll(['-map', '[vout]']);
    if (audioPath != null) {
      args.addAll(['-map', '$N:a', '-c:a', 'aac', '-b:a', '128k', '-shortest']);
    }
    args.addAll(['-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-y', outputPath]);
    return args;
  }

  String _scaleFilter(SlideshowQuality quality) {
    final w = quality.width;
    final h = quality.height;
    return 'scale=$w:$h:force_original_aspect_ratio=decrease,'
        'pad=$w:$h:(ow-iw)/2:(oh-ih)/2,setsar=1';
  }
}
