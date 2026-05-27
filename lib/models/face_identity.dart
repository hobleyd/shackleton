import 'dart:typed_data';

class FaceIdentity {
  final int? id;
  final String name;
  final Float32List embedding;

  const FaceIdentity({this.id, required this.name, required this.embedding});

  factory FaceIdentity.fromMap(Map<String, dynamic> map) => FaceIdentity(
        id: map['id'] as int?,
        name: map['name'] as String,
        embedding: Float32List.sublistView(map['embedding'] as Uint8List),
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'embedding': Uint8List.view(embedding.buffer),
      };
}
