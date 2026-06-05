import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/use_cases/load_metadata_use_case.dart';
import '../models/file_of_interest.dart';
import '../providers/exif_tool_service_provider.dart';
import '../repositories/app_settings_repository.dart';
import '../repositories/file_tags_repository.dart';

part 'metadata_cache_warmer.g.dart';

@immutable
class MetadataCacheWarmState {
  final int completed;
  final int total;

  const MetadataCacheWarmState({this.completed = 0, this.total = 0});

  bool get isVisible => total > 0;
}

@Riverpod(keepAlive: true)
class MetadataCacheWarmer extends _$MetadataCacheWarmer {
  late LoadMetadataUseCase _loadUseCase;
  late FileTagsRepository _tagsRepo;

  StreamSubscription<FileSystemEvent>? _watchSub;
  final _queue = <FileOfInterest>[];
  bool _running = false;
  int _completed = 0;
  int _total = 0;
  // Incremented on each build() so stale async tasks can self-cancel.
  int _version = 0;

  @override
  MetadataCacheWarmState build() {
    final exifService = ref.read(exifToolServiceProvider);
    _tagsRepo = ref.read(fileTagsRepositoryProvider.notifier);
    _loadUseCase = LoadMetadataUseCase(
      exifService: exifService,
      tagsRepository: _tagsRepo,
    );

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

    final settingsAsync = ref.watch(appSettingsRepositoryProvider);
    final tagsRepoAsync = ref.watch(fileTagsRepositoryProvider);

    final libraryPath = settingsAsync.asData?.value.libraryPath;
    if (libraryPath != null && tagsRepoAsync.hasValue) {
      _init(version, libraryPath);
    }

    return const MetadataCacheWarmState();
  }

  void _init(int version, String libraryPath) async {
    if (_version != version || !ref.mounted) return;
    _startWatching(libraryPath, version);
    await _enqueueUnindexed(libraryPath, version);
    if (_version != version || !ref.mounted) return;
    _runQueue(version);
  }

  static const _batchSize = 500;

  Future<void> _enqueueUnindexed(String rootPath, int version) async {
    final dir = Directory(rootPath);
    if (!dir.existsSync()) return;

    final batch = <String>[];

    Future<void> flushBatch() async {
      if (batch.isEmpty || _version != version || !ref.mounted) return;
      final indexed = await _tagsRepo.getIndexedPathsFromSet(List.of(batch));
      for (final path in batch) {
        if (!indexed.contains(path)) {
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
          if (foi.isMetadataSupported) {
            batch.add(entity.path);
            if (batch.length >= _batchSize) await flushBatch();
          }
        }
      }
    } catch (_) {}

    await flushBatch();

    if (ref.mounted && _total > 0) {
      state = MetadataCacheWarmState(completed: _completed, total: _total);
    }
  }

  void _addToQueue(FileOfInterest foi) {
    _queue.add(foi);
    _total++;
    if (ref.mounted) state = MetadataCacheWarmState(completed: _completed, total: _total);
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
        await _loadUseCase.execute(foi);
      } catch (_) {}
      _completed++;
      if (ref.mounted) state = MetadataCacheWarmState(completed: _completed, total: _total);
    }

    _completed = 0;
    _total = 0;
    if (ref.mounted) state = const MetadataCacheWarmState();
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
            await _enqueueUnindexed(event.path, version);
          } else {
            final foi = FileOfInterest(entity: File(event.path));
            if (foi.isMetadataSupported &&
                !await _tagsRepo.getIndexedPathsFromSet([foi.path])
                    .then((s) => s.contains(foi.path))) {
              _addToQueue(foi);
            }
          }
          if (!_running) _runQueue(version);
        },
      );
    } catch (_) {}
  }
}
