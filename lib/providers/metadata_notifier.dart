import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/metadata.dart';
import '../models/tag.dart';

part 'metadata_notifier.g.dart';

@riverpod
class MetadataNotifier extends _$MetadataNotifier {
  @override
  FileMetaData build(FileSystemEntity entity) {
    debugPrint('building new MetadataNotifier: $entity');
    loadMetadataFromFile(entity);
    return const FileMetaData(tags: []);
  }

  bool isMetadataSupported(FileSystemEntity entity) {
    const Set<String> supportedExtensions = { 'jpg', 'tiff' };

    return supportedExtensions.contains(entity.path.split('.').last);
  }

  Future<void> loadMetadataFromFile(FileSystemEntity entity) async {
    if (isMetadataSupported(entity)) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-subject', entity.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          saveTags(output.stdout);
          //TODO: Tag.writeTags(_fileCache, entity, tags);
          //cachedStorageNotifierProvider.cacheTagsForEntity(entity, tags);
        }
      }
    }
  }

  void removeTags(Tag tag) {
    List<Tag> tags = [
      for (var t in state.tags)
        if (t != tag)
          t
    ];

    state = FileMetaData(tags: tags);
  }

  void saveTags(String tags) {
    Set<Tag> tagSet = state.tags.toSet();
    tagSet.addAll(tags.split(',').map((e) => Tag(tag: e.trim())));

    List<Tag> tagList = tagSet.toList();
    tagList.sort();

    state = state.copyWith(tags: tagList, isEditing: false);
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}