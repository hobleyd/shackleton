import 'dart:typed_data';

abstract class IFaceRecognitionService {
  Future<bool> get modelsAvailable;

  Future<void> downloadModels({
    void Function(String message, double progress)? onProgress,
  });

  Future<List<FaceDetection>> detectFaces(String imagePath);

  double cosineSimilarity(Float32List a, Float32List b);

  void dispose();
}

class FaceDetection {
  final double bboxX;
  final double bboxY;
  final double bboxW;
  final double bboxH;
  final double confidence;
  final List<List<double>> landmarks;
  final Float32List embedding;

  const FaceDetection({
    required this.bboxX,
    required this.bboxY,
    required this.bboxW,
    required this.bboxH,
    required this.confidence,
    required this.landmarks,
    required this.embedding,
  });
}
