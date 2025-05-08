import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../misc/utils.dart';
import '../../models/shackleton_disk.dart';
import '../../providers/disk_size_details.dart';
import '../../providers/folder_path.dart';

class NavigationSpace extends ConsumerWidget {
  const NavigationSpace({super.key,});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, watch, child) {
      var diskAsync = ref.watch(diskSizeDetailsProvider);
      return diskAsync.when(
        error: (error, stackTrace) {
          return const Text('Wow! A diskless computer!');
        },
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        data: (List<ShackletonDisk> disks) {
          var folderPaths = ref.watch(folderPathProvider);

          ShackletonDisk? disk = _getDisk(disks, folderPaths.last);
          return disk == null
          ? const Text('Wow! A diskless computer!')
          : Row(
            children: [
              const SizedBox(width: 10),
              Column(children: [
                Text('Path:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Used:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Free:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Total:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
              ]),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(disk.mountPath, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.usedSpace), style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.availableSpace), style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.totalSize), style: Theme.of(context).textTheme.bodySmall),
              ]),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: SfRadialGauge(
                      axes: <RadialAxis>[
                        RadialAxis(
                          minimum: 0,
                          maximum: 100,
                          interval: 20,
                          labelFormat: '{value}%',
                          showLabels: false,
                          annotations: <GaugeAnnotation>[
                            GaugeAnnotation(
                              angle: 90,
                              positionFactor: 0.75,
                              widget: Text(' ${disk.usedPercentage.round()}%', style: Theme.of(context).textTheme.titleSmall),
                            ),
                          ],
                          ranges: <GaugeRange>[
                            GaugeRange(startValue: 0, endValue: 60, color: Colors.green),
                            GaugeRange(startValue: 60, endValue: 90, color: Colors.orange),
                            GaugeRange(startValue: 90, endValue: 100, color: Colors.red)
                          ],
                          pointers: <GaugePointer>[
                            NeedlePointer(
                              value: disk.usedPercentage,
                              needleStartWidth: 1.0,
                              needleEndWidth: 2.0,
                            )
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    });
  }

  ShackletonDisk? _getDisk(List<ShackletonDisk> disks, FileSystemEntity entity) {
    for (var disk in disks) {
      if (Platform.isWindows) {
        if (entity.path.startsWith(disk.mountPath) ||
            entity.path.startsWith(disk.devicePath) ||
            entity.absolute.path
                .toUpperCase() // Must convert both sides to upper case since Windows paths are case invariant
                .startsWith(disk.mountPath.toUpperCase()) ||
            entity.absolute.path
                .toUpperCase()
                .startsWith(disk.devicePath.toUpperCase())) {
          return disk;
        }
      } else if (Platform.isLinux || Platform.isMacOS) {
        if (entity.path.startsWith(disk.mountPath) || entity.path.startsWith(disk.devicePath) || entity.absolute.path.startsWith(disk.mountPath) ||
            entity.absolute.path.startsWith(disk.devicePath)) {
          return disk;
        }
      }
    }

    return null;
  }
}