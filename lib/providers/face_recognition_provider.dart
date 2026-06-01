import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/use_cases/scan_faces_use_case.dart';
import '../domain/services/i_face_recognition_service.dart';
import '../models/face_identity.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';
import '../providers/exif_tool_service_provider.dart';
import '../providers/face_recognition_service_provider.dart';
import '../providers/metadata.dart';
import '../repositories/faces_repository.dart';
import '../repositories/file_tags_repository.dart';

part 'face_recognition_provider.g.dart';

enum FaceSearchStatus { idle, downloadingModels, detecting, scanning, tagging, done, error }

class FaceSearchState {
  final FaceSearchStatus status;
  final String message;
  final double progress;
  final List<({FileOfInterest file, double similarity, String personName})> results;
  final String? errorMessage;
  final List<FaceDetection>? referenceFaces;
  final String? referencePath;

  const FaceSearchState({
    this.status = FaceSearchStatus.idle,
    this.message = '',
    this.progress = 0.0,
    this.results = const [],
    this.errorMessage,
    this.referenceFaces,
    this.referencePath,
  });

  FaceSearchState copyWith({
    FaceSearchStatus? status,
    String? message,
    double? progress,
    List<({FileOfInterest file, double similarity, String personName})>? results,
    String? errorMessage,
    List<FaceDetection>? referenceFaces,
    String? referencePath,
  }) =>
      FaceSearchState(
        status: status ?? this.status,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        results: results ?? this.results,
        errorMessage: errorMessage ?? this.errorMessage,
        referenceFaces: referenceFaces ?? this.referenceFaces,
        referencePath: referencePath ?? this.referencePath,
      );
}

@Riverpod(keepAlive: true)
class FaceSearch extends _$FaceSearch {
  late final IFaceRecognitionService _faceService;

  @override
  FaceSearchState build() {
    _faceService = ref.read(faceRecognitionServiceProvider);
    return const FaceSearchState();
  }

  void reset() => state = const FaceSearchState();

  Future<void> downloadModels() async {
    state = state.copyWith(
      status: FaceSearchStatus.downloadingModels,
      message: 'Preparing to download…',
      progress: 0.0,
    );
    try {
      await _faceService.downloadModels(
        onProgress: (msg, p) {
          if (ref.mounted) {
            state = state.copyWith(message: msg, progress: p);
          }
        },
      );
      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.idle,
          message: 'Models ready',
          progress: 1.0,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.error,
          errorMessage: 'Download failed: $e',
        );
      }
    }
  }

  /// Detects all faces in [file] and stores them in state for the user to name.
  Future<void> detectReferenceFaces(FileOfInterest file) async {
    state = state.copyWith(
      status: FaceSearchStatus.detecting,
      message: 'Checking models…',
      progress: 0.0,
    );

    if (!await _faceService.modelsAvailable) {
      await downloadModels();
      if (!ref.mounted || state.status == FaceSearchStatus.error) return;
      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.detecting,
          message: 'Detecting faces…',
        );
      }
    }

    try {
      if (ref.mounted) {
        state = state.copyWith(message: 'Detecting faces…');
      }
      final faces = await _faceService.detectFaces(file.path);
      // Sort left-to-right by bbox x so face numbering matches visual order.
      faces.sort((a, b) => a.bboxX.compareTo(b.bboxX));

      if (ref.mounted) {
        if (faces.isEmpty) {
          state = FaceSearchState(
            status: FaceSearchStatus.error,
            errorMessage: 'No faces detected in this photo.',
            referencePath: file.path,
          );
        } else {
          state = FaceSearchState(
            status: FaceSearchStatus.idle,
            message: '${faces.length} face${faces.length == 1 ? '' : 's'} detected',
            referenceFaces: faces,
            referencePath: file.path,
          );
        }
      }
    } catch (e) {
      if (ref.mounted) {
        state = FaceSearchState(
          status: FaceSearchStatus.error,
          errorMessage: 'Detection failed: $e',
          referencePath: file.path,
        );
      }
    }
  }

  /// Scans the library once and finds matches for all [namedFaces].
  Future<void> search({
    required List<({FaceDetection face, String name})> namedFaces,
    required double threshold,
    required List<FileOfInterest> libraryFiles,
  }) async {
    if (namedFaces.isEmpty) return;

    state = state.copyWith(
      status: FaceSearchStatus.scanning,
      message: 'Checking models…',
      progress: 0.0,
      results: [],
    );

    final facesRepo = ref.read(facesRepositoryProvider.notifier);

    if (!await _faceService.modelsAvailable) {
      await downloadModels();
      if (!ref.mounted || state.status == FaceSearchStatus.error) return;
    }

    try {
      // Upsert all named identities up-front.
      if (ref.mounted) state = state.copyWith(message: 'Saving identities…');
      final withIdentity = <({FaceDetection face, String name, FaceIdentity identity})>[];
      for (final nf in namedFaces) {
        final identity = await facesRepo.upsertIdentity(nf.name.trim(), nf.face.embedding);
        withIdentity.add((face: nf.face, name: nf.name.trim(), identity: identity));
      }

      // Scan library once — skips already-scanned files.
      if (ref.mounted) state = state.copyWith(message: 'Scanning library for faces…');
      final scanUseCase = ScanFacesUseCase(
        faceService: _faceService,
        facesRepo: facesRepo,
      );
      await scanUseCase.execute(
        libraryFiles,
        onProgress: (p, file) {
          if (ref.mounted) {
            state = state.copyWith(
              progress: p * 0.9,
              message: file.isEmpty ? 'Querying database…' : 'Scanning: ${_basename(file)}',
            );
          }
        },
      );

      // Query matches per person and merge results.
      if (ref.mounted) state = state.copyWith(message: 'Finding matches…', progress: 0.92);
      final allMatches = <({FileOfInterest file, double similarity, String personName})>[];
      for (final id in withIdentity) {
        final matches = await facesRepo.findFilesMatchingIdentity(
          id.identity,
          threshold,
          excludeTagName: id.name,
        );
        for (final m in matches) {
          allMatches.add((file: m.file, similarity: m.similarity, personName: id.name));
        }
      }

      // Sort by similarity descending.
      allMatches.sort((a, b) => b.similarity.compareTo(a.similarity));

      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.done,
          message: '${allMatches.length} photo${allMatches.length == 1 ? '' : 's'} found',
          progress: 1.0,
          results: allMatches,
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.error,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// Tags every result file with its matched person's name.
  Future<void> tagAll() async {
    final results = state.results;
    if (results.isEmpty) return;

    final exif = ref.read(exifToolServiceProvider);
    final tagsRepo = ref.read(fileTagsRepositoryProvider.notifier);
    final total = results.length;

    if (ref.mounted) {
      state = state.copyWith(
        status: FaceSearchStatus.tagging,
        message: 'Tagging photos…',
        progress: 0.0,
      );
    }

    var lastProgressUpdate = DateTime.now();

    for (var i = 0; i < total; i++) {
      if (!ref.mounted) return;
      final match = results[i];
      final file = match.file;
      final name = match.personName;
      final newTag = Tag(tag: name);

      if (exif.findExifTool() != null && file.isMetadataSupported) {
        try {
          final result = await exif.readTagsAndLocation(file.path);
          final tags = List<Tag>.from(result.tags);
          if (!tags.any((t) => t.tag == name)) tags.add(newTag);
          await exif.writeTags(file.path, tags, location: result.location);
        } catch (_) {
          // DB-only path below handles the update.
        }
      }

      await tagsRepo.addTagToFile(file.path, name);

      if (ref.exists(metadataProvider(file))) {
        ref.read(metadataProvider(file).notifier).updateTagsFromString(name, updateFile: false);
      }

      final now = DateTime.now();
      if (ref.mounted && (i == total - 1 || now.difference(lastProgressUpdate).inMilliseconds >= 150)) {
        lastProgressUpdate = now;
        state = state.copyWith(
          progress: (i + 1) / total,
          message: 'Tagged ${i + 1} of $total…',
        );
        await Future.delayed(Duration.zero);
      }
    }

    if (ref.mounted) {
      state = state.copyWith(
        status: FaceSearchStatus.done,
        results: [],
        message: '$total photo${total == 1 ? '' : 's'} tagged',
        progress: 1.0,
      );
    }
  }

  String _basename(String p) {
    final sep = Platform.isWindows ? '\\' : '/';
    return p.split(sep).last;
  }
}
