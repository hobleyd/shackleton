import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../repositories/folder_settings_repository.dart';

class FolderSettingsIcons extends ConsumerWidget {
  final Directory path;
  final KeyboardHandler handler;
  final bool showHiddenFiles;
  final bool showDetailedView;

  const FolderSettingsIcons({super.key, required this.path, required this.handler, required this.showHiddenFiles, required this.showDetailedView});

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
            onPressed: () => newEntity(ref),
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

  void newEntity(WidgetRef ref) {
    FolderContents contents = ref.read(folderContentsProvider(path).notifier);
    FileOfInterest entity = FileOfInterest(entity: path.createTempSync('new-'), editing: true);
    contents.add(entity);
    handler.setEditing(true);
  }
}