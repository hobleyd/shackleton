class Tag implements Comparable {
  int? id;
  String tag;

  Tag({
    this.id,
    required this.tag,
  });

  @override
  int compareTo(other) => tag.compareTo(other.tag);

  @override
  get hashCode => tag.hashCode;

  @override
  bool operator ==(other) => other is Tag && tag == other.tag;

  static Tag fromMap(Map<String, dynamic> tag) {
    return Tag(
      id: tag['id'],
      tag: tag['tag'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tag': tag,
    };
  }

  @override
  String toString() {
    return tag;
  }
}
