import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:process_run/cmd_run.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../misc/windows_usb_listener.dart';
import '../models/shackleton_disk.dart';

part 'disk_size_details.g.dart';

double roundDouble(double value, int places) {
  var mod = pow(10.0, places);
  return ((value * mod).round().toDouble() / mod);
}

@Riverpod(keepAlive: true)
class DiskSizeDetails extends _$DiskSizeDetails {
  @override
  Future<List<ShackletonDisk>> build() async {
    if (Platform.isWindows) {
      // Required to track removable disks being added/removed.
      subscribeToUSBEvents();
    }

    return _getDisks();
  }

  Future<List<ShackletonDisk>> _getDisks() async {
    List<ShackletonDisk> disks = [];

    if (!Platform.isWindows) {
      DiskSpace diskSpace = DiskSpace();
      await diskSpace.scan();

      for (var disk in diskSpace.disks) {
        disks.add(ShackletonDisk(
            devicePath: disk.devicePath,
            mountPath: disk.mountPath,
            totalSize: disk.totalSize,
            usedSpace: disk.usedSpace,
            usedPercentage: roundDouble(((disk.totalSize - disk.availableSpace) / disk.totalSize) * 100.0, 2),
            availableSpace: disk.availableSpace));
      }
    } else {
      final powerShell = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe';
      final powerShellArgs = [
        '-command',
        'Get-WmiObject', '-Class', 'Win32_LogicalDisk',
        '|',
        'Select', 'DeviceID,', 'DriveType,', 'ProviderName,', 'FreeSpace,', 'Size,', 'VolumeName',
        '|',
        'ConvertTo-Csv', '-NoTypeInformation'
      ];

      ProcessResult psResult = await runExecutableArguments(powerShell, powerShellArgs);
      final List<String> volumeLines = LineSplitter().convert(psResult.stdout);
      for (int i = 1; i < volumeLines.length; i++) {
        List<String> volumes = volumeLines[i].split(',');

        try {
          final String devicePath = volumes[0].replaceAll('"', '');
          final Directory mountDir = Directory(devicePath);
          if (mountDir.existsSync()) {
            final int freeSpace = volumes[3].isNotEmpty ? int.parse(volumes[3].replaceAll('"', '')) : 0;
            final int totalSize = volumes[4].isNotEmpty ? int.parse(volumes[4].replaceAll('"', '')) : 0;
            final int usedSpace = totalSize - freeSpace;
            final String mountPath = volumes[2].replaceAll('"', '');
            final String driveLabel = volumes[5].replaceAll('"', '');
            final int driveType = volumes[1].isNotEmpty ? int.parse(volumes[4].replaceAll('"', '')) : 0;

            disks.add(ShackletonDisk(
                devicePath: devicePath,
                mountPath: mountPath.isNotEmpty ? mountPath : devicePath,
                totalSize: totalSize,
                usedSpace: usedSpace,
                usedPercentage: roundDouble((usedSpace / totalSize) * 100.0, 2),
                availableSpace: freeSpace,
                isRemovable: driveType == 2 || driveType == 4,
                label: driveLabel));
          }
        } catch (e) {
          // existsSync() can return a FileSystemException if it fails!
          continue;
        }
      }
    }

    return disks;
  }

  void scanDisks() async {
    state = AsyncValue.data(await _getDisks());
  }

  void subscribeToUSBEvents() async {
    onUsbDriveChanged.listen((message) {
      final {
        'event': event as String,
        'drive': drive as String,
        'info': info as String?,
      } = message;
      scanDisks();
    }, cancelOnError: true);
  }
}

