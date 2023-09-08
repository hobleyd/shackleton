import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import 'folder_path.dart';

part 'disk_size_details.g.dart';

double roundDouble(double value, int places){
  var mod = pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}

extension DiskPercentage on Disk {
  // You might ask why we don't just use usedSpace, but on MacOS, used + available != total. Sigh.
  get usedPercentage => roundDouble(((totalSize - availableSpace) / totalSize) * 100.0, 2);
}

@riverpod
class DiskSizeDetails extends _$DiskSizeDetails {
  @override
  Future<Disk> build() async {
    final disks = DiskSpace();
    await disks.scan();

    var folderPaths = ref.watch(folderPathProvider);
    return disks.getDisk(folderPaths.last);
  }
}