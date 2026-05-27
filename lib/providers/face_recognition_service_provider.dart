import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/i_face_recognition_service.dart';
import '../services/face_recognition_service.dart';

final faceRecognitionServiceProvider = Provider<IFaceRecognitionService>(
  (ref) {
    final svc = FaceRecognitionService();
    ref.onDispose(svc.dispose);
    return svc;
  },
);
