import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../providers/selected_entities/selected_entities.dart';
import 'entity_context_menu.dart';
import 'navigation/navigation_favourites.dart';
import 'navigation/navigation_mounted_drives.dart';
import 'navigation/navigation_space.dart';
import 'navigation/navigation_tags.dart';

class Navigation extends ConsumerStatefulWidget {
  const Navigation({Key? key,}) : super(key: key);

  @override
  ConsumerState<Navigation> createState() => _Navigation();
}

class _Navigation extends ConsumerState<Navigation> {
  final linuxMountFolder = Directory('/media');
  final macosMountFolder = Directory('/Volumes');
  double _width = 250;
  bool mouseHover = false;

  @override
  Widget build(BuildContext context) {
    ScrollController controller = ScrollController();

    return Row(children: [
      SizedBox(
        width: _width,
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              mouseHover = true;
            });
          },
          onExit: (_) {
            mouseHover = false;
          },
          child: Container(
            alignment: Alignment.topLeft,
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.4),
            child: EntityContextMenu(
              fileType: FileType.folderList,
              folder: FileOfInterest(entity: Directory(getHomeFolder())),
              child: Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
                child: SingleChildScrollView(
                  controller: controller,
                  child: Column(
                    children: [
                      const NavigationSpace(),
                      Container(color: Theme.of(context).primaryColorLight, height: 2),
                      const NavigationFavourites(),
                      if (Platform.isMacOS || Platform.isLinux) ...[
                        const SizedBox(height: 10),
                        NavigationMountedDrives(mountPoint: Platform.isMacOS ? macosMountFolder : linuxMountFolder),
                      ],
                      const SizedBox(height: 10),
                      const NavigationTags(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              setState(() {
                _width += details.delta.dx;
              });
            },
            child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
          )),
    ]);
  }
}