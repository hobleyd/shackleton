import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'file_of_interest.dart';
import 'tag.dart';

@immutable
class FileMetaData implements Comparable {
  final FileOfInterest? entity;
  final List<Tag> tags;
  final bool isEditing;
  final LatLng? gpsLocation;
  final bool corruptedMetadata;

  @override
  get hashCode => tags.hashCode;
  get hasTags => tags.isNotEmpty;

  @override
  bool operator ==(other) => other is FileMetaData && gpsLocation == other.gpsLocation && toString() == other.toString();

  @override
  int compareTo(other) => toString().compareTo(other.toString());

  const FileMetaData({
    this.entity,
    required this.tags,
    this.isEditing = false,
    this.gpsLocation,
    this.corruptedMetadata = false,
  });

  bool contains(Tag tag) => tags.contains(tag);

  FileMetaData copyWith({FileOfInterest? entity, List<Tag>? tags, bool? isEditing, LatLng? gpsLocation, bool? corruptedMetadata}) {
    return FileMetaData(
      entity: entity ?? this.entity,
      tags: tags ?? this.tags,
      isEditing: isEditing ?? this.isEditing,
      gpsLocation: gpsLocation ?? this.gpsLocation,
      corruptedMetadata: corruptedMetadata ?? this.corruptedMetadata,
    );
  }

  @override
  String toString() {
    return tags.toString();
  }
}