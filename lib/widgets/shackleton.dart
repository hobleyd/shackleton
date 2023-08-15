import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:process_run/process_run.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../models/preview_settings.dart';
import '../models/tag.dart';
import '../providers/folder_path.dart';
import '../providers/folder_settings.dart';
import '../providers/metadata.dart';
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
            IconButton(icon: const Icon(Icons.import_export), tooltip: 'Import images from folder...', onPressed: () => _importImages(ref)),
            IconButton(icon: const Icon(Icons.sync), tooltip: 'Cache metadata...', onPressed: () => _cacheMetadata(ref)),
            IconButton(icon: const Icon(Icons.preview_sharp), tooltip: 'Show the Preview pane...', onPressed: () => ref.read(previewProvider.notifier).setVisibility(!preview.visible)),
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
                        children:
                            paths.map((e) => SizedBox(width: ref.watch(folderSettingsProvider(e)).width, child: FolderList(path: e))).toList())),
              ),
            ]),
        ),
    );
  }

  void _cacheMetadata(WidgetRef ref) async {
    Set<FileOfInterest> selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList));
    for (FileOfInterest foi in selectedEntities) {
      await _cacheFileOfInterest(ref, foi);
    }
  }

  Future<void> _cacheFileOfInterest(WidgetRef ref, FileOfInterest foi) async {
    if (foi.isDirectory) {
      Directory d = foi.entity as Directory;
      for (var entity in d.listSync()) {
        await _cacheFileOfInterest(ref, FileOfInterest(entity: entity));
      }
    } else {
      var metadata = ref.read(metadataProvider(foi).notifier);
      Set<Tag> tags = await metadata.getTagsFromFile(foi);
      await metadata.replaceTags(foi, tags, update: false);
    }
  }

  void _importImages(WidgetRef ref) async {
    Set<FileOfInterest> selectedEntities = ref.read(selectedEntitiesProvider(FileType.folderList));
    for (FileOfInterest foi in selectedEntities) {
      await _importImagesFromFolder(ref, foi);
    }
  }

  Future<void> _importImagesFromFolder(WidgetRef ref, FileOfInterest foi) async {
    if (foi.isDirectory) {
      Directory d = foi.entity as Directory;
      for (var entity in d.listSync()) {
        await _importImagesFromFolder(ref, FileOfInterest(entity: entity));
      }
    } else if (foi.isFile && foi.isImage){
      String path = await _getPathInLibrary(foi);
      File libraryEntity = File(path);
      if (!libraryEntity.existsSync()) {
        libraryEntity = await moveFile(foi.entity as File, path);
      } else {
        if (getFileSha256(libraryEntity) != getFileSha256(foi.entity as File)) {
          await moveFile(foi.entity as File, path);
          await _cacheFileOfInterest(ref, FileOfInterest(entity: libraryEntity));
        }
      }
    }
  }

  Future<String> _getPathInLibrary(FileOfInterest foi) async {
    if (foi.isImage && foi.exists) {
      bool hasExiftool = whichSync('exiftool') != null ? true : false;

      if (hasExiftool) {
        ProcessResult output = await runExecutableArguments('exiftool', ['-s', '-s', '-s', '-CreateDate', foi.path]);
        if (output.exitCode == 0 && output.stdout.isNotEmpty) {
          // Create Date: 2016:06:26 14:46:58
          String creationDate = output.stdout.split(':').last.trim();
          DateTime creationDateTime = DateFormat("yyyy:mm:dd HH:mm:ss").parse(creationDate);
          String year = DateFormat('yyyy').format(creationDateTime);
          String month = DateFormat('mm - MMMM').format(creationDateTime);
        }
      }
    }

    return "";
  }
}