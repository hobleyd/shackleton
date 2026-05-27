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

enum FaceSearchStatus { idle, downloadingModels, scanning, done, error }

class FaceSearchState {
  final FaceSearchStatus status;
  final String message;
  final double progress;
  final List<({FileOfInterest file, double similarity})> results;
  final String? errorMessage;
  final FaceIdentity? identity;

  const FaceSearchState({
    this.status = FaceSearchStatus.idle,
    this.message = '',
    this.progress = 0.0,
    this.results = const [],
    this.errorMessage,
    this.identity,
  });

  FaceSearchState copyWith({
    FaceSearchStatus? status,
    String? message,
    double? progress,
    List<({FileOfInterest file, double similarity})>? results,
    String? errorMessage,
    FaceIdentity? identity,
  }) =>
      FaceSearchState(
        status: status ?? this.status,
        message: message ?? this.message,
        progress: progress ?? this.progress,
        results: results ?? this.results,
        errorMessage: errorMessage ?? this.errorMessage,
        identity: identity ?? this.identity,
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

  Future<void> search({
    required FileOfInterest referenceFile,
    required String personName,
    required double threshold,
    required List<FileOfInterest> libraryFiles,
  }) async {
    if (personName.trim().isEmpty) return;

    // Give immediate visual feedback before any async work.
    state = state.copyWith(
      status: FaceSearchStatus.scanning,
      message: 'Checking models…',
      progress: 0.0,
      results: [],
    );

    final facesRepo = ref.read(facesRepositoryProvider.notifier);

    // 1. Ensure models are present.
    if (!await _faceService.modelsAvailable) {
      await downloadModels();
      if (!ref.mounted || state.status == FaceSearchStatus.error) return;
    }

    if (ref.mounted) {
      state = state.copyWith(
        message: 'Detecting face in reference photo…',
      );
    }

    try {
      // 2. Detect faces in reference photo and pick the most confident one.
      final referenceFaces = await _faceService.detectFaces(referenceFile.path);
      if (referenceFaces.isEmpty) {
        if (ref.mounted) {
          state = state.copyWith(
            status: FaceSearchStatus.error,
            errorMessage: 'No face detected in the reference photo.',
          );
        }
        return;
      }
      referenceFaces.sort((a, b) => b.confidence.compareTo(a.confidence));
      final refEmbedding = referenceFaces.first.embedding;

      // 3. Upsert the identity using the reference embedding.
      final identity = await facesRepo.upsertIdentity(personName.trim(), refEmbedding);
      if (ref.mounted) {
        state = state.copyWith(
          message: 'Scanning library for faces…',
          identity: identity,
        );
      }

      // 4. Scan unscanned library files.
      final scanUseCase = ScanFacesUseCase(
        faceService: _faceService,
        facesRepo: facesRepo,
      );
      await scanUseCase.execute(
        libraryFiles,
        onProgress: (p, file) {
          if (ref.mounted) {
            state = state.copyWith(
              progress: p * 0.9, // reserve last 10% for DB query
              message: file.isEmpty ? 'Querying database…' : 'Scanning: ${_basename(file)}',
            );
          }
        },
      );

      // 5. Query for matching files not yet tagged with this person.
      if (ref.mounted) {
        state = state.copyWith(message: 'Finding matches…', progress: 0.92);
      }
      final matches = await facesRepo.findFilesMatchingIdentity(
        identity,
        threshold,
        excludeTagName: personName.trim(),
      );

      if (ref.mounted) {
        state = state.copyWith(
          status: FaceSearchStatus.done,
          message: '${matches.length} photo${matches.length == 1 ? '' : 's'} found',
          progress: 1.0,
          results: matches,
          identity: identity,
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

  /// Tags all result files with [personName] and removes them from results.
  ///
  /// Writes via exiftool so the file's IPTC tags are updated; the metadata
  /// provider reload (triggered by invalidation) then syncs those tags back to
  /// the DB via LoadMetadataUseCase. Falls back to DB-only when exiftool is
  /// absent or the file doesn't support IPTC metadata.
  Future<void> tagAll(String personName) async {
    final name = personName.trim();
    if (name.isEmpty) return;
    final exif = ref.read(exifToolServiceProvider);
    final tagsRepo = ref.read(fileTagsRepositoryProvider.notifier);
    final newTag = Tag(tag: name);

    for (final match in state.results) {
      final file = match.file;
      if (exif.findExifTool() != null && file.isMetadataSupported) {
        try {
          final result = await exif.readTagsAndLocation(file.path);
          final tags = List<Tag>.from(result.tags);
          if (!tags.any((t) => t.tag == name)) tags.add(newTag);
          await exif.writeTags(file.path, tags, location: result.location);
          ref.invalidate(metadataProvider(file));
        } catch (_) {
          await tagsRepo.addTagToFile(file.path, name);
        }
      } else {
        await tagsRepo.addTagToFile(file.path, name);
      }
    }

    if (ref.mounted) {
      state = state.copyWith(
        results: [],
        message: 'All photos tagged as "$name"',
      );
    }
  }

  String _basename(String p) {
    final sep = Platform.isWindows ? '\\' : '/';
    return p.split(sep).last;
  }
}
