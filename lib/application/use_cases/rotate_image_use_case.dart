import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../models/file_of_interest.dart';

class RotateImageUseCase {
  /// Rotates the image at [entity] by [degrees] in-place and returns the
  /// encoded bytes ready for in-memory display. Returns null if the image
  /// cannot be decoded.
  Future<Uint8List?> execute(FileOfInterest entity, int degrees) async {
    final imageFile = entity.entity as File;
    final originalBytes = await imageFile.readAsBytes();
    // Newer versions of package:image throw on unrecognised/corrupt data
    // rather than returning null, so treat both as "cannot be decoded".
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(originalBytes);
    } on img.ImageException {
      return null;
    }
    if (decoded == null) return null;

    final rotated = img.copyRotate(decoded, angle: degrees);
    final encoded = switch (entity.extension) {
      'jpg' || 'jpeg' => img.encodeJpg(rotated),
      'png'           => img.encodePng(rotated),
      'tif' || 'tiff' => img.encodeTiff(rotated),
      'gif'           => img.encodeGif(rotated),
      _               => originalBytes,
    };

    await imageFile.writeAsBytes(encoded);
    return encoded;
  }
}
