import 'package:latlong2/latlong.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/exceptions.dart';
import '../application/use_cases/load_metadata_use_case.dart';
import '../application/use_cases/save_metadata_use_case.dart';
import '../domain/services/i_exif_tool_service.dart';
import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';
import '../providers/exif_tool_service_provider.dart';
import '../providers/notify.dart';
import '../repositories/file_tags_repository.dart';

part 'metadata.g.dart';

@riverpod
class Metadata extends _$Metadata {
  late IExifToolService _exif;
  late LoadMetadataUseCase _loadUseCase;
  late SaveMetadataUseCase _saveUseCase;
  late dynamic _notify;

  @override
  FileMetaData build(FileOfInterest entity) {
    // keepAlive() is NOT called here — providers for off-screen items can be
    // auto-disposed. keepAlive() is called lazily once data is in hand so
    // that providers with loaded state are cached, while providers that never
    // got to load (scrolled away quickly) are cleaned up automatically.
    _exif = ref.read(exifToolServiceProvider);
    final tags = ref.read(fileTagsRepositoryProvider.notifier);
    _notify = ref.read(notifyProvider.notifier);
    _loadUseCase = LoadMetadataUseCase(exifService: _exif, tagsRepository: tags);
    _saveUseCase = SaveMetadataUseCase(exifService: _exif, tagsRepository: tags);
    _load(entity);
    return const FileMetaData(entity: null, tags: []);
  }

  bool get hasExifTool => _exif.findExifTool() != null;

  bool contains(Tag tag) => state.contains(tag);

  Future<void> _load(FileOfInterest entity) async {
    // Phase 1: return cached DB data immediately — no JPEG parse needed.
    final cached = await _loadUseCase.fetchFromDb(entity);
    if (cached != null) {
      if (ref.mounted) {
        ref.keepAlive();
        state = cached;
      }
      return;
    }
    // Phase 2: first visit — parse the file via exiftool and persist to DB.
    // Gate on ref.mounted: if the item has scrolled out of the cache extent
    // the provider will have been auto-disposed, making it pointless (and
    // harmful) to queue another serialised daemon call. This keeps the daemon
    // queue bounded to currently-visible items instead of every item ever seen.
    if (!ref.mounted) return;
    ref.keepAlive();
    final metadata = await _loadUseCase.execute(entity);
    if (metadata != null && ref.mounted) state = metadata;
  }

  void removeTags(Tag tag) {
    final tags = [for (var t in state.tags) if (t != tag) t];
    state = state.copyWith(tags: tags);
    saveMetadata(updateFile: true);
  }

  Future<bool> saveMetadata({bool updateFile = false}) async {
    try {
      final updated = await _saveUseCase.execute(state, updateFile: updateFile);
      if (ref.mounted) state = updated;
      return true;
    } on ExifToolMissingException {
      _notify.addNotification(
          message: 'exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.');
      return false;
    } on MetadataWriteException catch (e) {
      _notify.addNotification(message: 'Unable to write metadata to ${e.fileName}');
      if (ref.mounted) state = state.copyWith(corruptedMetadata: true);
      return false;
    }
  }

  Future<bool> setLocation(LatLng location) async {
    state = state.copyWith(gpsLocation: location);
    return saveMetadata(updateFile: true);
  }

  Future<bool> replaceTagsFromString(String tags, {bool updateFile = true}) async {
    state = state.copyWith(tags: _exif.parseTagsFromString(tags));
    if (updateFile) return saveMetadata(updateFile: true);
    return true;
  }

  void updateTagsFromString(String tags, {bool updateFile = true}) {
    final newTags = List<Tag>.from(state.tags)..addAll(_exif.parseTagsFromString(tags));
    state = state.copyWith(tags: [...{...newTags}]);
    if (updateFile) saveMetadata(updateFile: true);
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}
