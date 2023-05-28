class Entity  {
  int? id;
  String path;

  Entity({
    this.id,
    required this.path,
  });

  static Entity fromMap(Map<String, dynamic> entity) {
    return Entity(
      id: entity['id'],
      path: entity['path'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'path': path,
    };
  }
}