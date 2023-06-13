import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:process_run/cmd_run.dart';
import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';

part 'metadata.g.dart';

@riverpod
class Metadata extends _$Metadata {
  @override
  FileMetaData build(FileOfInterest entity) {
    loadMetadataFromFile(entity);
    return const FileMetaData(tags: []);
  }

  Future<void> loadMetadataFromFile(FileOfInterest entity) async {
    if (entity.isMetadataSupported) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-subject', entity.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          replaceTags(entity, output.stdout, update: false);
          //TODO: Tag.writeTags(_fileCache, entity, tags);
          //cachedStorageNotifierProvider.cacheTagsForEntity(entity, tags);
        }
      }
    }
  }

  void removeTags(FileOfInterest entity, Tag tag) {
    List<Tag> tags = [
      for (var t in state.tags)
        if (t != tag)
          t
    ];

    String tagString = "";
    if (tags.isNotEmpty) {
      tagString = tags.toString();
      tagString = tagString.substring(1, tagString.length-1);
    }

    saveMetadataToFile(entity, tagString);

    state = FileMetaData(tags: tags);
  }

  Future<bool> saveMetadataToFile(FileOfInterest entity, String tags) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-overwrite_original', '-subject=$tags', entity.path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        if (output.outText.trim() == '1 image files updated') {
          return true;
        }
      }
    }

    return false;
  }

  void replaceTags(FileOfInterest entity, String tags, {bool update = true}) async {
    updateTags(entity, tags, tagSet: {}, update: update);
  }

  void updateTags(FileOfInterest entity, String tags, {Set<Tag>? tagSet, bool update = true}) async {
    Set<Tag> newTags = tagSet ?? state.tags.toSet();

    newTags.addAll(tags.split(',').map((e) => Tag(tag: e.trim())));

    List<Tag> tagList = newTags.toList();
    tagList.sort();

    if (update) {
      String tagString = "";
      if (tagList.isNotEmpty) {
        tagString = tagList.toString();
        tagString = tagString.substring(1, tagString.length - 1);
      }

      // If we want to save to file, then we only update state once the file is written.
      if (await saveMetadataToFile(entity, tagString)) {
        state = state.copyWith(tags: tagList, isEditing: false);
      }
    } else {
      // Otherwise, we are reading from the file and only want to update the provider.
      state = state.copyWith(tags: tagList, isEditing: false);
    }
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}