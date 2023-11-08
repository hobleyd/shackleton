import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:latlong2/latlong.dart';
import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/misc/utils.dart';

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

  Future<LatLng?> getLocationFromFile(FileOfInterest entity) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-n', '-s', '-s', '-s', '-gpslatitude', '-gpslongitude', entity.path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        List<String> location = output.stdout.split('\n');
        debugPrint('location: $location');
        try {
          return LatLng(double.parse(location[0]), double.parse(location[1]));
        } on FormatException {}
      }
    }

    return null;
  }

  Future<FileMetaData> getMetadata(FileOfInterest entity) async {
    List<Tag> tags = await getTagsFromFile(entity);
    LatLng? location = await getLocationFromFile(entity);

    return FileMetaData(tags: tags, gpsLocation: location);
  }

  Future<List<Tag>> getTagsFromFile(FileOfInterest entity) async {
    if (entity.isMetadataSupported) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-subject', entity.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          List<Tag> tagList = [];
          tagList.addAll(getTagsFromString(output.stdout));

          return tagList;
        }
      }
    }
    return [];
  }

  String getStringFromTags(List<Tag> tags) {
    String tagString = "";
    if (tags.isNotEmpty) {
      tagString = tags.toString();
      tagString = tagString.substring(1, tagString.length-1);
    }

    return tagString;
  }

  List<Tag> getTagsFromString(String tags) {
    return tags.split(',').map((e) => Tag(tag: e.trim())).toList();
  }

  Future<void> loadMetadataFromFile(FileOfInterest entity) async {
    if (entity.isMetadataSupported) {
      List<Tag> tags = await getTagsFromFile(entity);
      LatLng? location = await getLocationFromFile(entity);

      state = FileMetaData(tags: tags, gpsLocation: location);
    }
  }

  void removeTags(FileOfInterest entity, Tag tag) {
    List<Tag> tags = [
      for (var t in state.tags)
        if (t != tag)
          t
    ];

    state = state.copyWith(tags: tags);
    saveMetadata(entity);
  }

  Future<bool> saveMetadata(FileOfInterest entity, { bool updateFile = false }) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    // Always write tags to DB even if file writing fails? I feel like this makes sense.
    // ignore: avoid_manual_providers_as_generated_provider_dependency
    ref.read(tagQueueProvider.notifier).queue(Entity(path: entity.path, metadata: state));

    if (updateFile) {
      String tagString = getStringFromTags(state.tags);
      String latitude = getLocation(state, true).replaceAll("'", "\\'").replaceAll('"', '\\"');
      String longitude = getLocation(state, false).replaceAll("'", "\\'").replaceAll('"', '\\"');

      debugPrint('$latitude, $longitude');
      if (hasExiftool && entity.isMetadataSupported) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-overwrite_original', '-subject=$tagString', "-gpslatitude=$latitude", "-gpslongitude=$longitude", entity.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          if (output.outText.trim() == '1 image files updated') {
            return true;
          }
        }
      }
    }

    return false;
  }

  Future<bool> setLocation(FileOfInterest entity, LatLng location) async {
    state = state.copyWith(gpsLocation: location);
    return saveMetadata(entity, updateFile: true);
  }

  Future<bool> replaceTagsFromString(FileOfInterest entity, String tags) async {
    state = state.copyWith(tags: getTagsFromString(tags));
    return saveMetadata(entity, updateFile: true);
  }

  void updateTagsFromString(FileOfInterest entity, String tags) {
    List<Tag> newTags = List.from(state.tags);
    newTags.addAll(getTagsFromString(tags));
    state = state.copyWith(tags: [...{...newTags}]);
    saveMetadata(entity);
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}