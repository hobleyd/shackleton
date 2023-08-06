import 'package:flutter/foundation.dart';

import 'tag.dart';

@immutable
class FileMetaData {
  final List<Tag> tags;
  final bool isEditing;

  get hasTags => tags.isNotEmpty;

  const FileMetaData({
    required this.tags,
    this.isEditing = false,
  });

  bool contains(Tag tag) => tags.contains(tag);

  FileMetaData copyWith({List<Tag>? tags, bool? isEditing}) {
    return FileMetaData(
      tags: tags ?? this.tags,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  @override
  String toString() {
    return tags.toString();
  }
}