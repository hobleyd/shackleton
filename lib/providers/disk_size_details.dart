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
  Map<String, String> _networkDrives = {};

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
        'get-wmiobject',
        'Win32_volume',
        '|',
        'select',
        'Name, Freespace, Capacity, DriveType, Label'
      ];

      if (_networkDrives.isEmpty) {
        _networkDrives = await _getNetworkDrives();
      }

      ProcessResult psResult = await runExecutableArguments(powerShell, powerShellArgs);
      final List<String> volumeLines = LineSplitter().convert(psResult.stdout);
      List<List<String>> results = volumeLines.map((line) => line.split(',')).toList();
      results.removeWhere((list) => list.first.isEmpty);

      for (int i = 0; i < results.length / 5; i++) {
        final String devicePath = results[(i * 5) + 0].first.split(' : ').last;
        final String mountPath = _networkDrives.containsKey(devicePath) ? _networkDrives[devicePath]! : devicePath;
        final int freeSpace = int.parse(results[(i * 5) + 1].first.split(' : ').last);
        final int capacity = int.parse(results[(i * 5) + 2].first.split(' : ').last);
        final String driveType = results[(i * 5) + 3].first.split(' : ').last;
        final String label = results[(i * 5) + 4].first.split(' : ').last;

        final mountDir = Directory(mountPath);
        if (mountDir.existsSync()) {
          // Only care about Windows mounted drives at this point
          if (devicePath.endsWith(':\\')) {
            disks.add(ShackletonDisk(
                devicePath: devicePath.substring(0, devicePath.length - 1),
                mountPath: mountPath.substring(0, mountPath.length - 1),
                totalSize: capacity,
                usedSpace: capacity - freeSpace,
                usedPercentage: roundDouble(((capacity - freeSpace) / capacity) * 100.0, 2),
                availableSpace: freeSpace,
                isRemovable: driveType == "2" || driveType == "4",
                label: label));
          }
        }
      }
    }

    return disks;
  }

  Future<Map<String, String>> _getNetworkDrives() async {
    final String net = r'C:\Windows\System32\net.exe';
    final List<String> netArgs = ['use'];

    ProcessResult netResult = await runExecutableArguments(net, netArgs);
    final List<String> netLines = LineSplitter().convert(netResult.stdout);

    Map<String, String> networkDrives = {};
    for (String line in netLines) {
      if (line.trim().isEmpty || line.startsWith('The command') || line.startsWith('New connections') || line.startsWith('-----')) {
        continue;
      }

      String netDrive = line.substring(13, 15);
      if (netDrive.endsWith(':')) {
        // If the network path is too long, the 'Microsoft Windows Network' gets pushed to a newline; so no need to do anything if we
        // don't have a drive letter as it is this (spare) line we are on.
        String remote = line.substring(23);

        if (remote.endsWith('Microsoft Windows Network')) {
          remote = remote.substring(0, remote.length - 25);
        }
        remote = remote.trim();
        networkDrives[netDrive] = remote;
      }
    }

    return networkDrives;
  }

  void _setDisks() async {
    state = AsyncValue.data(await _getDisks());
  }

  void subscribeToUSBEvents() async {
    onUsbDriveChanged.listen((message) {
      final {
        'event': event as String,
        'drive': drive as String,
        'info': info as String?,
      } = message;
      _setDisks();
    }, cancelOnError: true);
  }
}

