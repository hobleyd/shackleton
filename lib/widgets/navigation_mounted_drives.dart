import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:process_run/cmd_run.dart';
import 'package:shackleton/providers/folder_contents.dart';
import 'package:shackleton/providers/folder_path.dart';

class NavigationMountedDrives extends ConsumerStatefulWidget {
  final Directory mountPoint;
  const NavigationMountedDrives({Key? key, required this.mountPoint}) : super(key: key);

  @override
  ConsumerState<NavigationMountedDrives> createState() => _NavigationMountedDrives();
}

class _NavigationMountedDrives extends ConsumerState<NavigationMountedDrives> {
  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      var mountPointRepository = ref.watch(folderContentsProvider(widget.mountPoint));
      if (Platform.isMacOS) {
        mountPointRepository.removeWhere((element) => element.name == 'Macintosh HD');
      }
      return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(Platform.isMacOS ? 'Locations' : 'Mounted Drives', textAlign: TextAlign.left, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 5),
          ListView.builder(
              itemCount: mountPointRepository.length,
              itemBuilder: (context, index) {
                return InkWell(
                  onTap: () => ref.read(folderPathProvider.notifier).setFolder(mountPointRepository[index].entity as Directory),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              mountPointRepository[index].name!,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                              icon: const Icon(Icons.eject),
                              constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                              iconSize: 12,
                              padding: EdgeInsets.zero,
                              splashRadius: 0.0001,
                              tooltip: 'Eject...',
                              onPressed: () => _unmountVolume(mountPointRepository[index].path!)),
                        ),
                      ),
                    ],
                  ),
                );
              },
              scrollDirection: Axis.vertical,
              shrinkWrap: true)
        ],
      );
    });
  }

  void _unmountVolume(String path) async {
    await runExecutableArguments('umount', [path]);
  }
}