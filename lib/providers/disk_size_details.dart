import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/services/i_disk_service.dart';
import '../models/shackleton_disk.dart';
import '../providers/disk_service_provider.dart';
import '../providers/notify.dart';

part 'disk_size_details.g.dart';

@Riverpod(keepAlive: true)
class DiskSizeDetails extends _$DiskSizeDetails {
  late final IDiskService _diskService;
  late final dynamic _notify;

  @override
  Future<List<ShackletonDisk>> build() async {
    _diskService = ref.read(diskServiceProvider);
    _notify = ref.read(notifyProvider.notifier);
    if (Platform.isWindows) {
      _diskService.driveChanges.listen((_) => scanDisks());
    }
    return _diskService.getDisks();
  }

  void scanDisks() async {
    final disks = await _diskService.getDisks();
    if (ref.mounted) state = AsyncValue.data(disks);
  }

  Future<void> unmountPath(String mountPath) async {
    final error = await _diskService.unmountPath(mountPath);
    if (error != null) _notify.addNotification(message: error);
  }

  Future<void> ejectDisk(ShackletonDisk disk) async {
    final error = await _diskService.ejectDisk(disk);
    if (error != null) {
      _notify.addNotification(message: error);
    } else {
      scanDisks();
    }
  }
}
