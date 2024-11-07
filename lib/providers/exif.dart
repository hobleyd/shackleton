import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../providers/error.dart';

part 'exif.g.dart';

@riverpod
class Exif extends _$Exif {
  @override
  Map<String, ({ String orig, String reset })> build(String path) {
    loadExifTags(path);
    return const {};
  }

  Future<bool> fixMetadata(String path) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-all=', '-tagsfromfile', '@', '-all:all', '-unsafe', '-icc_profile', path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        if (output.outText.trim() == '1 image files updated') {
          loadExifTags(path);
          return true;
        }
      } else {
        // ignore: avoid_manual_providers_as_generated_provider_dependency
        ref.read(errorProvider.notifier).setError('Resetting exif data failed for $path - ${output.stderr.trim()}');
        //TODO: state = state.copyWith(corruptedMetadata: true);
      }
    } else {
      // ignore: avoid_manual_providers_as_generated_provider_dependency
      ref.read(errorProvider.notifier).setError('exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.');
    }

    return false;
  }

  Future<void> loadExifTags(String path) async {
    Map<String, ({ String orig, String reset })> exifTags = {};

    bool hasExiftool = whichSync('exiftool') != null ? true : false;
    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        for (var exif in output.outLines) {
          List<String> exifData = exif.split(':');
          exifTags[exifData[0].trim()] = (orig: exifData[1].trim(), reset: '');
        }
      }

      output = await runExecutableArguments('exiftool', ['-s', '-s', '${path}_original']);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        for (var exif in output.outLines) {
          List<String> exifData = exif.split(':');
          var previous = exifTags[exifData[0].trim()];
          exifTags[exifData[0].trim()] = (orig: previous?.orig ?? '', reset: exifData[1].trim());
        }
      }
    }

    state = exifTags;
  }
}
