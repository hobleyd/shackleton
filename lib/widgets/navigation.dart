import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/folder_ui_settings.dart';
import '../repositories/folder_settings_repository.dart';
import 'navigation/navigation_favourites.dart';
import 'navigation/navigation_mounted_drives.dart';
import 'navigation/navigation_space.dart';
import 'navigation/navigation_tags.dart';

class Navigation extends ConsumerStatefulWidget {
  const Navigation({super.key,});

  @override
  ConsumerState<Navigation> createState() => _Navigation();
}

class _Navigation extends ConsumerState<Navigation> {
  final linuxMountFolder = Directory('/media');
  final macosMountFolder = Directory('/Volumes');
  bool mouseHover = false;

  @override
  Widget build(BuildContext context) {
    ScrollController controller = ScrollController();

    return Consumer(builder: (context, watch, child) {
      var folderSettings = ref.watch(folderSettingsRepositoryProvider(navigationFolder));
      return folderSettings.when(error: (error, stackTrace) {
        return Text('Failed to get settings', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (FolderUISettings folderSettings) {
        return Row(children: [
          SizedBox(
            width: folderSettings.width,
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
                color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
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
          MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                onHorizontalDragUpdate: (DragUpdateDetails details) {
                  var folderNotifier = ref.read(folderSettingsRepositoryProvider(navigationFolder).notifier);
                  folderNotifier.updateSettings(folderSettings.copyWith(width: folderSettings.width + details.delta.dx));
                },
                child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
              )),
        ]);
      });
    });
  }
}