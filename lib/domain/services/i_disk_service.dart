import '../../models/shackleton_disk.dart';

abstract class IDiskService {
  Future<List<ShackletonDisk>> getDisks();

  /// Ejects [disk]. Returns an error message on failure, null on success.
  Future<String?> ejectDisk(ShackletonDisk disk);

  /// Unmounts the volume at [mountPath] (e.g. a network share under /Volumes).
  /// Returns an error message on failure, null on success.
  Future<String?> unmountPath(String mountPath);

  /// Emits whenever the set of mounted drives changes.
  /// Only produces events on Windows (USB insertion/removal); empty on other
  /// platforms.
  Stream<void> get driveChanges;
}
