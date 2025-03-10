import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/widgets/folders/folder_pane_controller.dart';

import '../../repositories/folder_settings_repository.dart';

class FolderSettingsIcons extends ConsumerWidget {
  final Directory path;
  final FolderPaneController paneController;
  final bool showHiddenFiles;
  final bool showDetailedView;

  const FolderSettingsIcons({super.key, required this.path, required this.paneController, required this.showHiddenFiles, required this.showDetailedView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var folderNotifier = ref.read(folderSettingsRepositoryProvider(path.path).notifier);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Spacer(),
          IconButton(
            constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
            iconSize: 14,
            onPressed: () => folderNotifier.updateShowDetailedView(!showDetailedView),
            padding: const EdgeInsets.only(top: 5),
            splashRadius: 0.0001,
            tooltip: showDetailedView ? 'Show simple file list' : 'Show detailed file list',
            icon: Icon(showDetailedView ? Icons.list_outlined : Icons.view_week),
          ),
          const Spacer(),
          IconButton(
            constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
            iconSize: 14,
            onPressed: () => folderNotifier.updateShowHiddenFiles(!showHiddenFiles),
            padding: const EdgeInsets.only(top: 5),
            splashRadius: 0.0001,
            tooltip: showHiddenFiles ? 'Hide hidden files' : 'Show hidden files',
            icon: Icon(showHiddenFiles ? Icons.hdr_weak : Icons.hdr_strong),
          ),
          const Spacer(),
          IconButton(
            constraints: const BoxConstraints(minHeight: 14, maxHeight: 14),
            iconSize: 14,
            onPressed: () => paneController.newEntity(),
            padding: const EdgeInsets.only(top: 5),
            splashRadius: 0.0001,
            tooltip: 'New folder...',
            icon: const Icon(Icons.create_new_folder),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}