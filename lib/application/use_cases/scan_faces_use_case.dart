import '../../domain/repositories/i_faces_repository.dart';
import '../../domain/services/i_face_recognition_service.dart';
import '../../models/file_of_interest.dart';

class ScanFacesUseCase {
  final IFaceRecognitionService _faceService;
  final IFacesRepository _facesRepo;

  ScanFacesUseCase({
    required IFaceRecognitionService faceService,
    required IFacesRepository facesRepo,
  })  : _faceService = faceService,
        _facesRepo = facesRepo;

  /// Scans [files] for faces, skipping already-scanned files.
  /// Reports progress via [onProgress] (0.0–1.0) and current filename via [onFile].
  Future<void> execute(
    List<FileOfInterest> files, {
    void Function(double progress, String currentFile)? onProgress,
  }) async {
    final images = files.where((f) => f.isImage).toList();
    if (images.isEmpty) return;

    for (var i = 0; i < images.length; i++) {
      final file = images[i];
      onProgress?.call(i / images.length, file.path);

      if (await _facesRepo.hasBeenScanned(file.path)) continue;

      try {
        final detections = await _faceService.detectFaces(file.path);
        await _facesRepo.storeFaces(file.path, detections);
        await _facesRepo.markScanned(file.path);
      } catch (_) {
        // Mark as scanned even on error so we don't retry a corrupt file each run.
        await _facesRepo.markScanned(file.path);
      }
    }
    onProgress?.call(1.0, '');
  }
}
