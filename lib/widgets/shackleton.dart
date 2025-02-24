import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';

import '../models/file_of_interest.dart';
import '../models/folder_ui_settings.dart';
import '../models/map_settings.dart';
import '../models/preview_settings.dart';
import '../providers/contents/grid_contents.dart';
import '../providers/folder_path.dart';
import '../providers/error.dart';
import '../providers/map_pane.dart';
import '../providers/preview.dart';
import '../providers/contents/selected_folder_contents.dart';
import '../repositories/folder_settings_repository.dart';

import 'folders/folder_list.dart';
import 'import_folder.dart';
import 'navigation.dart';
import 'preview/preview_grid.dart';
import 'shackleton_settings.dart';

class Shackleton extends ConsumerStatefulWidget {
  const Shackleton({super.key});

  @override
  ConsumerState<Shackleton> createState() => _Shackleton();
}

class _Shackleton extends ConsumerState<Shackleton> {
  final ScrollController scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    List<Directory> paths = ref.watch(folderPathProvider);
    PreviewSettings preview = ref.watch(previewProvider);
    MapSettings map = ref.watch(mapPaneProvider);
    String error = ref.watch(errorProvider);

    Widget widgetState = Scaffold(
      appBar: AppBar(
        elevation: 2,
        shadowColor: Theme.of(context).shadowColor,
        title: Text(paths.map((e) => basename(e.path)).toList().toString(), style: Theme.of(context).textTheme.labelSmall),
        actions: <Widget>[
          IconButton(icon: const Icon(Icons.import_export), tooltip: 'Import images from folder...', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ImportFolder()))),
          IconButton(icon: const Icon(Icons.sync), tooltip: 'Cache metadata...', onPressed: () => _cacheMetadata(ref)),
          IconButton(icon: const Icon(Icons.map), tooltip: 'Show on Map', onPressed: () => _showMap(ref, map.visible)),
          IconButton(icon: const Icon(Icons.settings), tooltip: 'Settings', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ShackletonSettings()))),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Align(alignment: Alignment.center, child: SizedBox(height: preview.height, child: const PreviewGrid())),
          MouseRegion(
              cursor: SystemMouseCursors.resizeRow,
              child: GestureDetector(
                onVerticalDragUpdate: (DragUpdateDetails details) {
                  ref.read(previewProvider.notifier).changeHeight(details.delta.dy);
                },
                child: Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 3),
              )),
          Expanded(
            child: Scrollbar(
              thumbVisibility: true,
              controller: scrollController,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: scrollController,
                child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: paths.length + 1,
                    itemBuilder: (context, index) {
                      //folderKeys[index] = GlobalKey();
                      return index == 0 ? const Navigation() : FolderList(path: paths[index - 1]);
                    }),
              ),
            ),
          ),
          if (error.isNotEmpty)
            Container(
                color: Theme.of(context).colorScheme.error,
                width: MediaQuery.of(context).size.width,
                child: Text(error, style: Theme.of(context).textTheme.labelSmall, textAlign: TextAlign.center,),
            ),
        ]),
      ),
    );

    _ensureLatestFolderIsVisible(context);

    return widgetState;
  }

  // My single biggest problem with Flutter is how difficult it is to ensure the list value you want to be visible is actually visible.
  // Google, with the brainpower you have available, surely you can solve this nicely? And if anyone starts on GlobalKeys. Well, don't.
  void _ensureLatestFolderIsVisible(BuildContext context) {
    List<Directory> paths = ref.watch(folderPathProvider);

    WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) {
          final double screenWidth = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize.width;
          double totalWidth = 0;

          var folderSettings = ref.watch(folderSettingsRepositoryProvider(navigationFolder));
          folderSettings.whenData((value) => totalWidth += value.width);

          for (var path in paths) {
            var uiSettings = ref.watch(folderSettingsRepositoryProvider(path.path));
            uiSettings.whenData((value) => totalWidth += value.width);
          }

          if (totalWidth > screenWidth) {
            scrollController.animateTo(totalWidth - screenWidth, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
          }
        }
      });
  }

  void _cacheMetadata(WidgetRef ref) async {
    Set<FileOfInterest> selectedEntities = ref.read(selectedFolderContentsProvider);
    for (FileOfInterest foi in selectedEntities) {
      await foi.cacheFileOfInterest(ref);
    }
  }

  void _showMap(WidgetRef ref, bool visible) {
    if (ref.read(gridContentsProvider).isEmpty) {
      ref.read(errorProvider.notifier).setError('The Map is unavailable until you have selected items to preview!');
    } else {
      ref.read(mapPaneProvider.notifier).setVisibility(!visible);
      ref.read(errorProvider.notifier).setError('');
    }
  }
}