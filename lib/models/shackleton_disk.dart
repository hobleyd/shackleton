import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:process_run/cmd_run.dart';

import '../providers/error.dart';

class ShackletonDisk {
  /// The original device path such as `\\nasdrive` or `C:\` on Windows and
  /// `/dev/sdX` on Linux.
  final String devicePath;

  /// The path where this device is mounted such as `Z:\` on Windows and
  /// `/mount/user/disk` on Linux.
  final String mountPath;

  /// The disk's total size in bytes.
  final int totalSize;

  /// The disk's used space in bytes.
  final int usedSpace;

  // The disks used percentage.
  // You might ask why we don't just use usedSpace, but on MacOS, used + available != total. Sigh.
  final double usedPercentage;

  /// The disk's available space in bytes.
  final int availableSpace;

  // Only used on Windows
  final String label;

  // Only used on Windows
  final bool isRemovable;

  const ShackletonDisk({
    required this.devicePath,
    required this.mountPath,
    required this.totalSize,
    required this.usedSpace,
    required this.usedPercentage,
    required this.availableSpace,
    this.label = "",
    this.isRemovable = false,
  });

  @override
  String toString() {
    return label.isEmpty ? mountPath : '$label ($mountPath)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is ShackletonDisk &&
              runtimeType == other.runtimeType &&
              devicePath == other.devicePath &&
              mountPath == other.mountPath &&
              totalSize == other.totalSize &&
              usedSpace == other.usedSpace &&
              availableSpace == other.availableSpace;

  @override
  int get hashCode =>
      devicePath.hashCode ^
      mountPath.hashCode ^
      totalSize.hashCode ^
      usedSpace.hashCode ^
      availableSpace.hashCode;

  void eject(WidgetRef ref) async {
    ProcessResult result;
    if (Platform.isWindows) {
      result = await runExecutableArguments('powershell.exe', ['-command', '(New-Object -comObject Shell.Application).NameSpace(17).ParseName("$mountPath").InvokeVerb("Eject")']);
    } else {
      result = await runExecutableArguments('umount', [mountPath]);
    }

    if (result.exitCode != 0) {
      ref.read(errorProvider.notifier).setError(result.stderr ?? result.stdout);
    }
  }
}
