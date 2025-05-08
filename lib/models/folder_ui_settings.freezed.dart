// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'folder_ui_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FolderUISettings {
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  FileSystemEntity get entity;
  double get width;
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get detailedView;
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get showHiddenFiles;

  /// Create a copy of FolderUISettings
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FolderUISettingsCopyWith<FolderUISettings> get copyWith =>
      _$FolderUISettingsCopyWithImpl<FolderUISettings>(
          this as FolderUISettings, _$identity);

  /// Serializes this FolderUISettings to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FolderUISettings &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.detailedView, detailedView) ||
                other.detailedView == detailedView) &&
            (identical(other.showHiddenFiles, showHiddenFiles) ||
                other.showHiddenFiles == showHiddenFiles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, entity, width, detailedView, showHiddenFiles);

  @override
  String toString() {
    return 'FolderUISettings(entity: $entity, width: $width, detailedView: $detailedView, showHiddenFiles: $showHiddenFiles)';
  }
}

/// @nodoc
abstract mixin class $FolderUISettingsCopyWith<$Res> {
  factory $FolderUISettingsCopyWith(
          FolderUISettings value, $Res Function(FolderUISettings) _then) =
      _$FolderUISettingsCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      FileSystemEntity entity,
      double width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) bool detailedView,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      bool showHiddenFiles});
}

/// @nodoc
class _$FolderUISettingsCopyWithImpl<$Res>
    implements $FolderUISettingsCopyWith<$Res> {
  _$FolderUISettingsCopyWithImpl(this._self, this._then);

  final FolderUISettings _self;
  final $Res Function(FolderUISettings) _then;

  /// Create a copy of FolderUISettings
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entity = null,
    Object? width = null,
    Object? detailedView = null,
    Object? showHiddenFiles = null,
  }) {
    return _then(_self.copyWith(
      entity: null == entity
          ? _self.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as FileSystemEntity,
      width: null == width
          ? _self.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      detailedView: null == detailedView
          ? _self.detailedView
          : detailedView // ignore: cast_nullable_to_non_nullable
              as bool,
      showHiddenFiles: null == showHiddenFiles
          ? _self.showHiddenFiles
          : showHiddenFiles // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _FolderUISettings implements FolderUISettings {
  const _FolderUISettings(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      required this.entity,
      required this.width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required this.detailedView,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required this.showHiddenFiles});
  factory _FolderUISettings.fromJson(Map<String, dynamic> json) =>
      _$FolderUISettingsFromJson(json);

  @override
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  final FileSystemEntity entity;
  @override
  final double width;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  final bool detailedView;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  final bool showHiddenFiles;

  /// Create a copy of FolderUISettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FolderUISettingsCopyWith<_FolderUISettings> get copyWith =>
      __$FolderUISettingsCopyWithImpl<_FolderUISettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FolderUISettingsToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FolderUISettings &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.detailedView, detailedView) ||
                other.detailedView == detailedView) &&
            (identical(other.showHiddenFiles, showHiddenFiles) ||
                other.showHiddenFiles == showHiddenFiles));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, entity, width, detailedView, showHiddenFiles);

  @override
  String toString() {
    return 'FolderUISettings(entity: $entity, width: $width, detailedView: $detailedView, showHiddenFiles: $showHiddenFiles)';
  }
}

/// @nodoc
abstract mixin class _$FolderUISettingsCopyWith<$Res>
    implements $FolderUISettingsCopyWith<$Res> {
  factory _$FolderUISettingsCopyWith(
          _FolderUISettings value, $Res Function(_FolderUISettings) _then) =
      __$FolderUISettingsCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      FileSystemEntity entity,
      double width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) bool detailedView,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      bool showHiddenFiles});
}

/// @nodoc
class __$FolderUISettingsCopyWithImpl<$Res>
    implements _$FolderUISettingsCopyWith<$Res> {
  __$FolderUISettingsCopyWithImpl(this._self, this._then);

  final _FolderUISettings _self;
  final $Res Function(_FolderUISettings) _then;

  /// Create a copy of FolderUISettings
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? entity = null,
    Object? width = null,
    Object? detailedView = null,
    Object? showHiddenFiles = null,
  }) {
    return _then(_FolderUISettings(
      entity: null == entity
          ? _self.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as FileSystemEntity,
      width: null == width
          ? _self.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      detailedView: null == detailedView
          ? _self.detailedView
          : detailedView // ignore: cast_nullable_to_non_nullable
              as bool,
      showHiddenFiles: null == showHiddenFiles
          ? _self.showHiddenFiles
          : showHiddenFiles // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
