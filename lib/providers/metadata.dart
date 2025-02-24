import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:process_run/process_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shackleton/repositories/file_tags_repository.dart';


import '../models/entity.dart';
import '../models/file_metadata.dart';
import '../models/file_of_interest.dart';
import '../misc/utils.dart';
import '../models/tag.dart';
import '../providers/error.dart';

part 'metadata.g.dart';

@riverpod
class Metadata extends _$Metadata {
  @override
  FileMetaData build(FileOfInterest entity) {
    loadMetadataFromFile(entity);
    return const FileMetaData(entity: null, tags: []);
  }

  bool contains(Tag tag) => state.contains(tag);

  Future<LatLng?> getLocationFromFile(FileOfInterest entity) async {
    bool hasExiftool = whichSync('exiftool') != null ? true : false;

    if (hasExiftool) {
      ProcessResult output = await runExecutableArguments('exiftool', ['-n', '-s', '-s', '-s', '-gpslatitude', '-gpslongitude', entity.path]);
      if (output.exitCode == 0 && output.stdout.isNotEmpty) {
        List<String> location = output.stdout.split('\n');
        try {
          return LatLng(double.parse(location[0]), double.parse(location[1]));
        // ignore: empty_catches
        } on FormatException {}
      }
    } else {
      // ignore: avoid_manual_providers_as_generated_provider_dependency
      ref.read(errorProvider.notifier).setError('exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.');
    }

    return null;
  }

  Future<FileMetaData> getMetadata(FileOfInterest entity) async {
    List<Tag> tags = await getTagsFromFile(entity);
    LatLng? location = await getLocationFromFile(entity);

    return FileMetaData(entity: entity, tags: tags, gpsLocation: location);
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

      state = FileMetaData(entity: entity, tags: tags, gpsLocation: location);

      Future(() {
        ref.read(fileTagsRepositoryProvider.notifier).writeTags(Entity(path: entity.path, metadata: state));
      });
    }
  }

  void removeTags(Tag tag) {
    List<Tag> tags = [
      for (var t in state.tags)
        if (t != tag)
          t
    ];

    state = state.copyWith(tags: tags);
    saveMetadata(updateFile: true);
  }

  Future<bool> saveMetadata({ bool updateFile = false }) async {
    // Always write tags to DB even if file writing fails? I feel like this makes sense.
    // ignore: avoid_manual_providers_as_generated_provider_dependency
    ref.read(fileTagsRepositoryProvider.notifier).writeTags(Entity(path: state.entity!.path, metadata: state));

    if (updateFile) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      String tagString = getStringFromTags(state.tags);
      String latitude = getLocation(state, true).replaceAll("'", "\\'").replaceAll('"', '\\"');
      String longitude = getLocation(state, false).replaceAll("'", "\\'").replaceAll('"', '\\"');

      if (hasExiftool && entity.isMetadataSupported) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-overwrite_original', '-subject=$tagString', "-gpslatitude=$latitude", "-gpslongitude=$longitude", state.entity!.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          if (output.outText.trim() == '1 image files updated') {
            state = state.copyWith(corruptedMetadata: false);
            return true;
          }
        } else {
          // ignore: avoid_manual_providers_as_generated_provider_dependency
          ref.read(errorProvider.notifier).setError('Unable to write metadata to ${state.entity!.name} - ${output.stderr.trim()}');
          state = state.copyWith(corruptedMetadata: true);
        }
      }
      else {
        // ignore: avoid_manual_providers_as_generated_provider_dependency
        ref.read(errorProvider.notifier).setError('exiftool not installed, please refer to https://github.com/hobleyd/shackleton for installation instructions.');
      }
    }

    return false;
  }

  Future<bool> setLocation(LatLng location) async {
    state = state.copyWith(gpsLocation: location);
    return saveMetadata(updateFile: true);
  }

  Future<bool> replaceTagsFromString(String tags, { bool updateFile = true }) async {
    state = state.copyWith(tags: getTagsFromString(tags));
    if (updateFile) {
      return saveMetadata(updateFile: true);
    } else {
      return true;
    }
  }

  void updateTagsFromString(String tags, { bool updateFile = true }) {
    List<Tag> newTags = List.from(state.tags);
    newTags.addAll(getTagsFromString(tags));
    state = state.copyWith(tags: [...{...newTags}]);
    if (updateFile) {
      saveMetadata(updateFile: true);
    }
  }

  void setEditable(bool editable) {
    state = state.copyWith(tags: state.tags, isEditing: editable);
  }
}