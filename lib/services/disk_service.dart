import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:process_run/cmd_run.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../domain/services/i_disk_service.dart';
import '../misc/windows_usb_listener.dart';
import '../models/shackleton_disk.dart';

class DiskService implements IDiskService {
  @override
  Future<List<ShackletonDisk>> getDisks() async {
    if (Platform.isWindows) return _getWindowsDisks();
    return _getUnixDisks();
  }

  @override
  Future<String?> ejectDisk(ShackletonDisk disk) async {
    final ProcessResult result;
    if (Platform.isWindows) {
      result = await runExecutableArguments('powershell.exe', [
        '-command',
        '(New-Object -comObject Shell.Application).NameSpace(17).ParseName("${disk.mountPath}").InvokeVerb("Eject")',
      ]);
    } else {
      result = await runExecutableArguments('umount', [disk.mountPath]);
    }

    if (result.exitCode != 0) {
      return result.stderr?.toString().isNotEmpty == true
          ? result.stderr.toString()
          : result.stdout.toString();
    }
    return null;
  }

  @override
  Future<String?> unmountPath(String mountPath) async {
    if (Platform.isWindows) return null;
    final result = await runExecutableArguments('umount', [mountPath]);
    if (result.exitCode != 0) {
      final msg = result.stderr?.toString() ?? '';
      return msg.isNotEmpty ? msg : result.stdout.toString();
    }
    return null;
  }

  @override
  Stream<void> get driveChanges {
    if (!Platform.isWindows) return const Stream.empty();
    return onUsbDriveChanged.map((_) {});
  }

  Future<List<ShackletonDisk>> _getUnixDisks() async {
    final diskSpace = DiskSpace();
    await diskSpace.scan();
    return [
      for (final disk in diskSpace.disks)
        ShackletonDisk(
          devicePath: disk.devicePath,
          mountPath: disk.mountPath,
          totalSize: disk.totalSize,
          usedSpace: disk.usedSpace,
          usedPercentage: _round(
              ((disk.totalSize - disk.availableSpace) / disk.totalSize) * 100.0,
              2),
          availableSpace: disk.availableSpace,
        ),
    ];
  }

  Future<List<ShackletonDisk>> _getWindowsDisks() async {
    const powerShell =
        r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
    final psResult = await runExecutableArguments(powerShell, [
      '-command',
      'Get-WmiObject', '-Class', 'Win32_LogicalDisk',
      '|',
      'Select', 'DeviceID,', 'DriveType,', 'ProviderName,', 'FreeSpace,',
      'Size,', 'VolumeName',
      '|',
      'ConvertTo-Csv', '-NoTypeInformation',
    ]);

    final disks = <ShackletonDisk>[];
    final lines = LineSplitter().convert(psResult.stdout.toString());
    for (int i = 1; i < lines.length; i++) {
      final volumes = lines[i].split(',');
      try {
        final devicePath = volumes[0].replaceAll('"', '');
        final mountDir = Directory(devicePath);
        if (!mountDir.existsSync()) continue;

        final freeSpace =
            volumes[3].isNotEmpty ? int.parse(volumes[3].replaceAll('"', '')) : 0;
        final totalSize =
            volumes[4].isNotEmpty ? int.parse(volumes[4].replaceAll('"', '')) : 0;
        final usedSpace = totalSize - freeSpace;
        final mountPath = volumes[2].replaceAll('"', '');
        final driveType =
            volumes[1].isNotEmpty ? int.parse(volumes[4].replaceAll('"', '')) : 0;

        String driveLabel = volumes[5].replaceAll('"', '');
        if (mountPath.isNotEmpty) {
          driveLabel = mountPath.split(r'\').last;
        }

        disks.add(ShackletonDisk(
          devicePath: devicePath,
          mountPath: mountPath.isNotEmpty ? mountPath : devicePath,
          totalSize: totalSize,
          usedSpace: usedSpace,
          usedPercentage: _round((usedSpace / totalSize) * 100.0, 2),
          availableSpace: freeSpace,
          isRemovable: driveType == 2 || driveType == 4,
          label: driveLabel,
        ));
      } catch (_) {
        continue;
      }
    }
    return disks;
  }

  static double _round(double value, int places) {
    final mod = pow(10.0, places);
    return ((value * mod).round().toDouble() / mod);
  }
}
