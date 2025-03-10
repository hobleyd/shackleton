import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/folder_ui_settings.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../repositories/folder_settings_repository.dart';
import 'folder_drop_zone.dart';

class FolderList extends ConsumerWidget {
  final Directory path;

  const FolderList({super.key, required this.path});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Consumer(builder: (context, watch, child) {
      var folderSettings = ref.watch(folderSettingsRepositoryProvider(path.path));
      return folderSettings.when(error: (error, stackTrace) {
        return Text('Failed to get settings', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (FolderUISettings folderSettings) {
        return GestureDetector(
            onTap: () => ref.read(selectedFolderContentsProvider.notifier).clear(),
            child: FolderDropZone(path: path, settings: folderSettings));
      });
    });
  }

}



