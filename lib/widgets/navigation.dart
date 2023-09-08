import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../providers/selected_entities.dart';
import 'entity_context_menu.dart';
import 'navigation_favourites.dart';
import 'navigation_space.dart';
import 'navigation_tags.dart';

class Navigation extends ConsumerWidget {
  const Navigation({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ScrollController controller = ScrollController();

    return Row(children: [
      SizedBox(
        width: 250,
        child: MouseRegion(
          onEnter: (_) {},
          onExit: (_) {},
          child: Container(
            alignment: Alignment.topLeft,
            color: const Color.fromRGBO(217, 217, 217, 100),
            decoration: false
                ? BoxDecoration(
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.teal,
                      width: 2,
                    ),
                  )
                : null,
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
                      Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 2),
                      const NavigationFavourites(),
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
            onHorizontalDragUpdate: (DragUpdateDetails details) {},
            child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
          )),
    ]);
  }
}