import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/services/i_face_recognition_service.dart';
import '../models/file_of_interest.dart';
import '../providers/face_recognition_service_provider.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/faces_repository.dart';

part 'face_cache_warmer.g.dart';

@immutable
class FaceCacheWarmState {
  final int completed;
  final int total;

  const FaceCacheWarmState({this.completed = 0, this.total = 0});

  bool get isVisible => total > 0;
}

@Riverpod(keepAlive: true)
class FaceCacheWarmer extends _$FaceCacheWarmer {
  late IFaceRecognitionService _faceService;
  late FacesRepository _facesRepo;

  StreamSubscription<FileSystemEvent>? _watchSub;
  final _queue = <FileOfInterest>[];
  bool _running = false;
  int _completed = 0;
  int _total = 0;
  // Incremented on each build() so stale async tasks can self-cancel.
  int _version = 0;

  @override
  FaceCacheWarmState build() {
    _faceService = ref.read(faceRecognitionServiceProvider);
    _facesRepo = ref.read(facesRepositoryProvider.notifier);

    // Cancel any in-flight scan from a previous build.
    _version++;
    final version = _version;
    _queue.clear();
    _running = false;
    _completed = 0;
    _total = 0;

    ref.onDispose(() {
      _watchSub?.cancel();
      _watchSub = null;
    });

    // Watch both providers — build() re-runs when settings load or change,
    // and when the faces repo finishes initialising.
    final settingsAsync = ref.watch(appSettingsRepositoryProvider);
    final facesRepoAsync = ref.watch(facesRepositoryProvider);

    final libraryPath = settingsAsync.asData?.value.libraryPath;
    if (libraryPath != null && facesRepoAsync.hasValue) {
      _init(version, libraryPath);
    }

    return const FaceCacheWarmState();
  }

  void _init(int version, String libraryPath) async {
    if (!await _faceService.modelsAvailable) return;
    if (_version != version || !ref.mounted) return;

    _startWatching(libraryPath, version);
    await _enqueueUnscanned(libraryPath, version);
    if (_version != version || !ref.mounted) return;
    _runQueue(version);
  }

  static const _batchSize = 500;

  Future<void> _enqueueUnscanned(String rootPath, int version) async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return;

    // Stream the filesystem and check each batch of 500 paths against the DB.
    // This keeps each DB query small (≤ 500 rows returned) rather than pulling
    // hundreds of thousands of scanned paths back in one blocking call.
    final batch = <String>[];

    Future<void> flushBatch() async {
      if (batch.isEmpty || _version != version || !ref.mounted) return;
      final scanned = await _facesRepo.getScannedPathsFromSet(List.of(batch));
      for (final path in batch) {
        if (!scanned.contains(path)) {
          _queue.add(FileOfInterest(entity: File(path)));
          _total++;
        }
      }
      batch.clear();
    }

    try {
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (_version != version) return;
        if (entity is File) {
          final foi = FileOfInterest(entity: entity);
          if (foi.isImage) {
            batch.add(entity.path);
            if (batch.length >= _batchSize) await flushBatch();
          }
        }
      }
    } catch (_) {}

    await flushBatch();

    if (ref.mounted && _total > 0) {
      state = FaceCacheWarmState(completed: _completed, total: _total);
    }
  }

  void _addToQueue(FileOfInterest foi) {
    _queue.add(foi);
    _total++;
    if (ref.mounted) state = FaceCacheWarmState(completed: _completed, total: _total);
  }

  void _runQueue(int version) async {
    if (_running) return;
    _running = true;

    while (_queue.isNotEmpty) {
      if (_version != version || !ref.mounted) {
        _running = false;
        return;
      }
      final foi = _queue.removeAt(0);
      try {
        final detections = await _faceService.detectFaces(foi.path);
        await _facesRepo.storeFaces(foi.path, detections);
        await _facesRepo.markScanned(foi.path);
      } catch (_) {
        try {
          await _facesRepo.markScanned(foi.path);
        } catch (_) {}
      }
      _completed++;
      if (ref.mounted) state = FaceCacheWarmState(completed: _completed, total: _total);
    }

    _completed = 0;
    _total = 0;
    if (ref.mounted) state = const FaceCacheWarmState();
    _running = false;
  }

  void _startWatching(String libraryPath, int version) {
    _watchSub?.cancel();
    try {
      _watchSub = Directory(libraryPath).watch(recursive: true).listen(
        (event) async {
          if (_version != version) return;
          if (event.type != FileSystemEvent.create) return;
          if (event.isDirectory) {
            await _enqueueUnscanned(event.path, version);
          } else {
            final foi = FileOfInterest(entity: File(event.path));
            if (foi.isImage && !await _facesRepo.hasBeenScanned(foi.path)) {
              _addToQueue(foi);
            }
          }
          if (!_running) _runQueue(version);
        },
      );
    } catch (_) {}
  }
}
