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
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

FolderUISettings _$FolderUISettingsFromJson(Map<String, dynamic> json) {
  return _FolderUISettings.fromJson(json);
}

/// @nodoc
mixin _$FolderUISettings {
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  FileSystemEntity get entity => throw _privateConstructorUsedError;
  double get width => throw _privateConstructorUsedError;
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get isDropZone => throw _privateConstructorUsedError;

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
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) bool isDropZone});
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
    Object? isDropZone = null,
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
      isDropZone: null == isDropZone
          ? _value.isDropZone
          : isDropZone // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_FolderUISettingsCopyWith<$Res>
    implements $FolderUISettingsCopyWith<$Res> {
  factory _$$_FolderUISettingsCopyWith(
          _$_FolderUISettings value, $Res Function(_$_FolderUISettings) then) =
      __$$_FolderUISettingsCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      FileSystemEntity entity,
      double width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson) bool isDropZone});
}

/// @nodoc
class __$$_FolderUISettingsCopyWithImpl<$Res>
    extends _$FolderUISettingsCopyWithImpl<$Res, _$_FolderUISettings>
    implements _$$_FolderUISettingsCopyWith<$Res> {
  __$$_FolderUISettingsCopyWithImpl(
      _$_FolderUISettings _value, $Res Function(_$_FolderUISettings) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? entity = null,
    Object? width = null,
    Object? isDropZone = null,
  }) {
    return _then(_$_FolderUISettings(
      entity: null == entity
          ? _value.entity
          : entity // ignore: cast_nullable_to_non_nullable
              as FileSystemEntity,
      width: null == width
          ? _value.width
          : width // ignore: cast_nullable_to_non_nullable
              as double,
      isDropZone: null == isDropZone
          ? _value.isDropZone
          : isDropZone // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$_FolderUISettings implements _FolderUISettings {
  const _$_FolderUISettings(
      {@JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
      required this.entity,
      required this.width,
      @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
      required this.isDropZone});

  factory _$_FolderUISettings.fromJson(Map<String, dynamic> json) =>
      _$$_FolderUISettingsFromJson(json);

  @override
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  final FileSystemEntity entity;
  @override
  final double width;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  final bool isDropZone;

  @override
  String toString() {
    return 'FolderUISettings(entity: $entity, width: $width, isDropZone: $isDropZone)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_FolderUISettings &&
            (identical(other.entity, entity) || other.entity == entity) &&
            (identical(other.width, width) || other.width == width) &&
            (identical(other.isDropZone, isDropZone) ||
                other.isDropZone == isDropZone));
  }

  @JsonKey(ignore: true)
  @override
  int get hashCode => Object.hash(runtimeType, entity, width, isDropZone);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_FolderUISettingsCopyWith<_$_FolderUISettings> get copyWith =>
      __$$_FolderUISettingsCopyWithImpl<_$_FolderUISettings>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$_FolderUISettingsToJson(
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
      required final bool isDropZone}) = _$_FolderUISettings;

  factory _FolderUISettings.fromJson(Map<String, dynamic> json) =
      _$_FolderUISettings.fromJson;

  @override
  @JsonKey(fromJson: _fseFromJson, toJson: _fseToJson)
  FileSystemEntity get entity;
  @override
  double get width;
  @override
  @JsonKey(fromJson: _boolFromJson, toJson: _boolToJson)
  bool get isDropZone;
  @override
  @JsonKey(ignore: true)
  _$$_FolderUISettingsCopyWith<_$_FolderUISettings> get copyWith =>
      throw _privateConstructorUsedError;
}