import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_of_interest.dart';
import '../models/preview_settings.dart';
import '../providers/folder_path.dart';
import '../providers/preview.dart';
import '../providers/selected_entities.dart';
import 'folder_list.dart';
import 'import_folder.dart';
import 'navigation.dart';
import 'preview_grid.dart';
import 'shackleton_settings.dart';

class Shackleton extends ConsumerWidget {
  const Shackleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ScrollController scrollController = ScrollController();
    List<Directory> paths = ref.watch(folderPathProvider);
    PreviewSettings preview = ref.watch(previewProvider);

    return Scaffold(
        appBar: AppBar(
          title: Text(paths.map((e) => e.path.split('/').last).toList().toString(), style: Theme.of(context).textTheme.labelSmall),
          actions: <Widget>[
            IconButton(icon: const Icon(Icons.import_export), tooltip: 'Import images from folder...', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ImportFolder()))),
            IconButton(icon: const Icon(Icons.sync), tooltip: 'Cache metadata...', onPressed: () => _cacheMetadata(ref)),
            IconButton(icon: const Icon(Icons.preview), tooltip: 'Preview', onPressed: () => ref.read(previewProvider.notifier).setVisibility(!preview.visible)),
            IconButton(icon: const Icon(Icons.settings), tooltip: 'Settings', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ShackletonSettings()))),
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Column(children: [
              if (preview.visible) ...{
                SizedBox(height: preview.height, child: const PreviewGrid()),
                MouseRegion(
                    cursor: SystemMouseCursors.resizeRow,
                    child: GestureDetector(
                      onVerticalDragUpdate: (DragUpdateDetails details) {
                        ref.read(previewProvider.notifier).changeHeight(details.delta.dy);
                      },
                      child: Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 3),
                    )),
              },
              Expanded(
                child: Scrollbar(
                    thumbVisibility: true,
                    controller: scrollController,
                    child: ListView(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        children: [
                            const Navigation(),
                            ...paths.map((e) => FolderList(path: e)).toList(),
                        ],
                    ),
                ),
              ),
            ]),
        ),
    );
  }

  void _cacheMetadata(WidgetRef ref) async {
    Set<FileOfInterest> selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList));
    for (FileOfInterest foi in selectedEntities) {
      await foi.cacheFileOfInterest(ref);
    }
  }
}