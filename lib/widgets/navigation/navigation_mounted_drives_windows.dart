import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/disk_size_details.dart';

import '../../models/shackleton_disk.dart';
import '../../providers/folder_path.dart';

class NavigationMountedDrivesWindows extends ConsumerStatefulWidget {
  const NavigationMountedDrivesWindows({super.key, });

  @override
  ConsumerState<NavigationMountedDrivesWindows> createState() => _NavigationMountedDrivesWindows();
}

class _NavigationMountedDrivesWindows extends ConsumerState<NavigationMountedDrivesWindows> {
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      var diskAsync = ref.watch(diskSizeDetailsProvider);
      return diskAsync.when(error: (error, stackTrace) {
        return const Text('Wow! A diskless computer!');
      }, loading: () {
        return const Center(child: CircularProgressIndicator());
      }, data: (List<ShackletonDisk> disks) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text('Mounted Drives', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 5),
            ListView.builder(
                itemCount: disks.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () => ref.read(folderPathProvider.notifier).setFolder(Directory(disks[index].mountPath)),
                    child: Stack(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                disks[index].label.isNotEmpty ? '${disks[index].label} (${disks[index].mountPath})' : disks[index].mountPath,
                                style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(width: 20),
                          ],
                        ),
                        if (disks[index].isRemovable) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 3, top: 3),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                  icon: const Icon(Icons.eject),
                                  constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                                  iconSize: 12,
                                  padding: EdgeInsets.zero,
                                  splashRadius: 0.0001,
                                  tooltip: 'Eject...',
                                  onPressed: () => _unmountVolume(disks[index])),
                            ),
                          )
                        ],
                      ],
                    ),
                  );
                },
                scrollDirection: Axis.vertical,
                shrinkWrap: true)
          ],
        );
      });
    });
  }

  void _unmountVolume(ShackletonDisk disk) async {
    disk.eject(ref);
  }
}