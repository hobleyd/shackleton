import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/preview_settings.dart';
import '../providers/folder_path.dart';
import '../providers/folder_settings.dart';
import '../providers/preview.dart';
import '../providers/selected_entities.dart';
import 'preview_grid.dart';
import 'folder_list.dart';

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
            IconButton(icon: const Icon(Icons.import_export), tooltip: 'Import images from folder...', onPressed: () => {}),
            IconButton(icon: const Icon(Icons.sync), tooltip: 'Cache metadata into database...', onPressed: () => {}),
            IconButton(icon: const Icon(Icons.preview_sharp), tooltip: 'Show the Preview pane...', onPressed: () => ref.read(previewProvider.notifier).setVisibility(!preview.visible)),
          ],
        ),
        body: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 6),
            child: Column(children: [
              if (preview.visible) ...{
                SizedBox(height: preview.height, child: const PreviewGrid(columnCount: 5, type: FileType.folderList)),
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
                        children:
                            paths.map((e) => SizedBox(width: ref.watch(folderSettingsProvider(e)).width, child: FolderList(path: e))).toList())),
              ),
            ]),
        ),
    );
  }
}