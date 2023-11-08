import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'tag.dart';

@immutable
class FileMetaData {
  final List<Tag> tags;
  final bool isEditing;
  final LatLng? gpsLocation;

  get hasTags => tags.isNotEmpty;

  const FileMetaData({
    required this.tags,
    this.isEditing = false,
    this.gpsLocation,
  });

  bool contains(Tag tag) => tags.contains(tag);

  FileMetaData copyWith({List<Tag>? tags, bool? isEditing, LatLng? gpsLocation,}) {
    return FileMetaData(
      tags: tags ?? this.tags,
      isEditing: isEditing ?? this.isEditing,
      gpsLocation: gpsLocation ?? this.gpsLocation,
    );
  }

  @override
  String toString() {
    return tags.toString();
  }
}