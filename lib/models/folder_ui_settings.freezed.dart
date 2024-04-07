// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'folder_ui_settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FolderUISettings _$FolderUISettingsFromJson(Map<String, dynamic> json) {
  return _FolderUISettings.fromJson(json);
}

/// @nodoc
mixin _$FolderUISettings {
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  FileSystemEntity get entity => throw _privateConstructorUsedError;
  double get width => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get detailedView => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get showHiddenFiles => throw _privateConstructorUsedError;

  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;
  @JsonKey(ignore: true)
  $FolderUISettingsCopyWith<FolderUISettings> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FolderUISettingsCopyWith<$Res> {
  factory $FolderUISettingsCopyWith(
          FolderUISettings value, $Res Function(FolderUISettings) then) =
      _$FolderUISettingsCopyWithImpl<$Res, FolderUISettings>;
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
class _$FolderUISettingsCopyWithImpl<$Res, $Val extends FolderUISettings>
    implements $FolderUISettingsCopyWith<$Res> {
  _$FolderUISettingsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entity = null,
    Object? width = null,
    Object? detailedView = null,
    Object? showHiddenFiles = null,
  }) {
    return _then(_value.copyWith(
      entity: null == entity
          ? _value.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as FileSystemEntity,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      detailedView: null == detailedView
          ? _value.detailedView
          : detailedView // ignore: cast_nullable_to_non_nullable
              as bool,
      showHiddenFiles: null == showHiddenFiles
          ? _value.showHiddenFiles
          : showHiddenFiles // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$FolderUISettingsImplCopyWith<$Res>
    implements $FolderUISettingsCopyWith<$Res> {
  factory _$$FolderUISettingsImplCopyWith(_$FolderUISettingsImpl value,
          $Res Function(_$FolderUISettingsImpl) then) =
      __$$FolderUISettingsImplCopyWithImpl<$Res>;
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
class __$$FolderUISettingsImplCopyWithImpl<$Res>
    extends _$FolderUISettingsCopyWithImpl<$Res, _$FolderUISettingsImpl>
    implements _$$FolderUISettingsImplCopyWith<$Res> {
  __$$FolderUISettingsImplCopyWithImpl(_$FolderUISettingsImpl _value,
      $Res Function(_$FolderUISettingsImpl) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entity = null,
    Object? width = null,
    Object? detailedView = null,
    Object? showHiddenFiles = null,
  }) {
    return _then(_$FolderUISettingsImpl(
      entity: null == entity
          ? _value.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as FileSystemEntity,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      detailedView: null == detailedView
          ? _value.detailedView
          : detailedView // ignore: cast_nullable_to_non_nullable
              as bool,
      showHiddenFiles: null == showHiddenFiles
          ? _value.showHiddenFiles
          : showHiddenFiles // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FolderUISettingsImpl implements _FolderUISettings {
  const _$FolderUISettingsImpl(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      required this.entity,
      required this.width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required this.detailedView,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required this.showHiddenFiles});

  factory _$FolderUISettingsImpl.fromJson(Map<String, dynamic> json) =>
      _$$FolderUISettingsImplFromJson(json);

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

  @override
  String toString() {
    return 'FolderUISettings(entity: $entity, width: $width, detailedView: $detailedView, showHiddenFiles: $showHiddenFiles)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FolderUISettingsImpl &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.detailedView, detailedView) ||
                other.detailedView == detailedView) &&
            (identical(other.showHiddenFiles, showHiddenFiles) ||
                other.showHiddenFiles == showHiddenFiles));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode =>
      Object.hash(runtimeType, entity, width, detailedView, showHiddenFiles);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$FolderUISettingsImplCopyWith<_$FolderUISettingsImpl> get copyWith =>
      __$$FolderUISettingsImplCopyWithImpl<_$FolderUISettingsImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FolderUISettingsImplToJson(
      this,
    );
  }
}

abstract class _FolderUISettings implements FolderUISettings {
  const factory _FolderUISettings(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      required final FileSystemEntity entity,
      required final double width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required final bool detailedView,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required final bool showHiddenFiles}) = _$FolderUISettingsImpl;

  factory _FolderUISettings.fromJson(Map<String, dynamic> json) =
      _$FolderUISettingsImpl.fromJson;

  @override
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  FileSystemEntity get entity;
  @override
  double get width;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get detailedView;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get showHiddenFiles;
  @override
  @JsonKey(ignore: true)
  _$$FolderUISettingsImplCopyWith<_$FolderUISettingsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
