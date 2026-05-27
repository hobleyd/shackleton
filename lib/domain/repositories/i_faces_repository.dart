import 'dart:typed_data';

import '../../domain/services/i_face_recognition_service.dart';
import '../../models/face_identity.dart';
import '../../models/file_of_interest.dart';

abstract class IFacesRepository {
  Future<FaceIdentity?> getIdentityByName(String name);
  Future<FaceIdentity> upsertIdentity(String name, Float32List embedding);
  Future<List<FaceIdentity>> getAllIdentities();

  Future<void> storeFaces(String path, List<FaceDetection> detections);
  Future<void> markScanned(String path);
  Future<bool> hasBeenScanned(String path);

  Future<List<({FileOfInterest file, double similarity})>> findFilesMatchingIdentity(
    FaceIdentity identity,
    double threshold, {
    String? excludeTagName,
  });
}
