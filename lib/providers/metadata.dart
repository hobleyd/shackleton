import 'dart:io';

import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/entity.dart';
import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';
import '../providers/tag_queue.dart';

part 'metadata.g.dart';

@riverpod
class Metadata extends _$Metadata {
  @override
  FileMetaData build(FileOfInterest entity) {
    loadMetadataFromFile(entity);
    return const FileMetaData(tags: []);
  }

  bool contains(Tag tag) => state.contains(tag);

  Future<Set<Tag>> getTagsFromFile(FileOfInterest entity) async {
    if (entity.isMetadataSupported) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-subject', entity.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          Set<Tag> tagList = {};
          tagList.addAll(getTagsFromString(output.stdout));

          return tagList;
        }
      }
    }
    return {};
  }

  String getStringFromTags(List<Tag> tags) {
    String tagString = "";
    if (tags.isNotEmpty) {
      tagString = tags.toString();
      tagString = tagString.substring(1, tagString.length-1);
    }

    return tagString;
  }

  Set<Tag> getTagsFromString(String tags) {
    return tags.split(',').map((e) => Tag(tag: e.trim())).toSet();
  }

  Future<void> loadMetadataFromFile(FileOfInterest entity) async {
    if (entity.isMetadataSupported) {
      Set<Tag> tags = await getTagsFromFile(entity);

      await replaceTags(entity, tags, update: false);
    }
  }

  void removeTags(FileOfInterest entity, Tag tag) {
    List<Tag> tags = [
      for (var t in state.tags)
        if (t != tag)
          t
    ];

    saveMetadata(entity, tags);

    state = FileMetaData(tags: tags);
  }

  Future<bool> saveMetadata(FileOfInterest entity, List<Tag> tags) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    // Always write tags to DB even if file writing fails? I feel like this makes sense.
    // ignore: avoid_manual_providers_as_generated_provider_dependency
    ref.read(tagQueueProvider.notifier).queue(Entity(path: entity.path, tags: tags.toSet()));

    String tagString = getStringFromTags(tags);
    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-overwrite_original', '-subject=$tagString', entity.path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        if (output.outText.trim() == '1 image files updated') {
          return true;
        }
      }
    }

    return false;
  }

  Future<void> replaceTags(FileOfInterest entity, Set<Tag> tags, {bool update = true}) async {
    updateTags(entity, tags, tagSet: {}, update: update);
  }

  Future<void> replaceTagsFromString(FileOfInterest entity, String tags) {
    return replaceTags(entity, getTagsFromString(tags));
  }

  void updateTags(FileOfInterest entity, Set<Tag> tags, {Set<Tag>? tagSet, bool update = true}) async {
    Set<Tag> newTags = tagSet ?? state.tags.toSet();
    newTags.addAll(tags);
    List<Tag> tagList = newTags.toList();
    tagList.sort();

    if (update) {
      // If we want to save to file, then we only update state once the file is written.
      if (await saveMetadata(entity, tagList)) {
        state = state.copyWith(tags: tagList, isEditing: false);
      }
    } else {
      // Otherwise, we are reading from the file and only want to update the provider.
      state = state.copyWith(tags: tagList, isEditing: false);
    }
  }

  void updateTagsFromString(FileOfInterest entity, String tags, {Set<Tag>? tagSet, bool update = true}) {
    return updateTags(entity, getTagsFromString(tags), tagSet: tagSet, update: update);
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}