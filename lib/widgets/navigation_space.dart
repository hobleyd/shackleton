import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:universal_disk_space/universal_disk_space.dart';

import '../misc/utils.dart';
import '../providers/disk_size_details.dart';

class NavigationSpace extends ConsumerWidget {
  const NavigationSpace({Key? key,}) : super(key: key);

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
        data: (Disk disk) {
          return Row(
            children: [
              const SizedBox(width: 10),
              Column(children: [
                Text('Path:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Used:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Free:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
                Text('Total:', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
              ]),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(disk.mountPath, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.usedSpace), style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.availableSpace), style: Theme.of(context).textTheme.bodySmall),
                Text(getSizeString(disk.totalSize), style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(width: 15),
              SizedBox(
                width: 80,
                height: 80,
                child: SfRadialGauge(
                  axes: <RadialAxis>[
                    RadialAxis(
                      minimum: 0,
                      maximum: 100,
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
            ],
          );
        },
      );
    });
  }
}