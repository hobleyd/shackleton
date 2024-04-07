import 'dart:io';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../misc/utils.dart';

part 'folder_ui_settings.freezed.dart';
part 'folder_ui_settings.g.dart';

FileSystemEntity _fseFromJson(String path) => getEntity(path);
String _fseToJson(FileSystemEntity entity) => entity.path;

bool _boolFromJson(int value) => value.isOdd;
int _boolToJson(bool value) => value ? 1 : 0;

const String navigationFolder = '**navigation**';

@freezed
class FolderUISettings with _$FolderUISettings {
  const factory FolderUISettings({
    @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson) required FileSystemEntity entity,
    required double width,
    @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) required bool detailedView,
    @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) required bool showHiddenFiles}) = _FolderUISettings;

  factory FolderUISettings.fromJson(Map<String, Object?> json) => _$FolderUISettingsFromJson(json);

}