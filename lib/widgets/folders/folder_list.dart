import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/editing_entity.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_of_interest.dart';
import '../../models/folder_ui_settings.dart';
import '../../providers/file_events.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../repositories/folder_settings_repository.dart';
import 'folder_drop_zone.dart';

class FolderList extends ConsumerStatefulWidget {
  final Directory path;

  const FolderList({super.key, required this.path});

  @override
  ConsumerState<FolderList> createState() => _FolderList();
}

class _FolderList extends ConsumerState<FolderList> implements KeyboardCallback {
  late KeyboardHandler handler;

  get folderPath => widget.path;

  @override
  Widget build(BuildContext context) {
    return Consumer(builder: (context, watch, child) {
      var folderSettings = ref.watch(folderSettingsRepositoryProvider(folderPath.path));
      return folderSettings.when(error: (error, stackTrace) {
        return Text('Failed to get settings', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (FolderUISettings folderSettings) {
        return FolderDropZone(path: folderPath, handler: handler, settings: folderSettings);
      });
    });
  }

  @override
  void dispose() {
    handler.deregister();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    handler = KeyboardHandler(ref: ref, keyboardCallback: this, name: 'FolderList');
    handler.register();
  }

  @override
  void delete() {
    var fileEvents = ref.read(fileEventsProvider.notifier);
    fileEvents.deleteAll(ref.watch(selectedFolderContentsProvider));
  }

  @override
  void down() {

  }

  @override
  void exit() {
    if (handler.isEditing) {
      FileOfInterest? entity = ref.read(editingEntityProvider);
      if (entity != null) {
        ref.read(editingEntityProvider.notifier).setEditingEntity(entity.path, null);
        handler.setEditing(false);
      }
    }
  }

  @override
  void left() {

  }

  @override
  void newEntity() {
    FolderContents contents = ref.read(folderContentsProvider(folderPath).notifier);
    FileOfInterest entity = FileOfInterest(entity: folderPath.createTempSync('new-'), editing: true);
    contents.add(entity);
    handler.setEditing(true);
  }

  @override
  void right() {

  }

  @override
  void up() {

  }

  @override
  void selectAll() {
    var selectedEntities = ref.read(selectedFolderContentsProvider.notifier);
    var entities = ref.read(folderContentsProvider(folderPath));
    selectedEntities.addAll(entities.toSet());
  }
}



