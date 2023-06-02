import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';
import 'package:path/path.dart' as path;

import '../models/file_of_interest.dart';
import '../models/metadata.dart';
import '../providers/metadata_notifier.dart';
import '../providers/selected_entities_notifier.dart';

class FileSystemEntityMetadata extends ConsumerWidget {
  FileOfInterest entity;
  late Set<FileOfInterest> selectedEntities;
  late FileMetaData metadata;

  FileSystemEntityMetadata({Key? key, required this.entity}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    selectedEntities = ref.watch(selectedEntitiesNotifierProvider(FileType.previewGrid));
    metadata = ref.watch(metadataNotifierProvider(entity));
    Color background = selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(entity.path.split(path.separator).last, style: Theme.of(context).textTheme.labelSmall),
        entity.isImage ? Expanded(child: Container(color: background, child: Image.file(File.fromUri(entity.uri), alignment: Alignment.center, fit: BoxFit.contain))) : const Expanded(child: Text('')),
        SizedBox(height: 5, child: Container(color: background)),
        metadata.isEditing ? _getEditableMetadata(context, ref) : _getMetadata(context, ref),
      ],
    );
  }

  Widget _getEditableMetadata(BuildContext context, WidgetRef ref) {
    TextEditingController tagController = TextEditingController();

    tagController.text = metadata.tags.isNotEmpty ? intersperse(', ', metadata.tags.map((e) => e.tag)).toString() : '';
    tagController.text = tagController.text.substring(1, tagController.text.length-1);

    return Row(children: [
      Expanded(child: TextField(
          decoration: const InputDecoration(border: InputBorder.none),
          autofocus: true,
          keyboardType: TextInputType.multiline,
          maxLines: null,
          controller: tagController,
          style: Theme.of(context).textTheme.bodySmall
      )),
      const Spacer(),
      IconButton(
          icon: const Icon(Icons.save),
          constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
          iconSize: 12,
          padding: EdgeInsets.zero,
          splashRadius: 0.0001,
          tooltip: 'Save comma separated list of Tags to file...',
          onPressed: () => ref.read(metadataNotifierProvider(entity).notifier).replaceTags(entity, tagController.text, update: true)),
    ]);
  }

  Widget _getMetadata(BuildContext context, WidgetRef ref) {
    return Container(
        color: selectedEntities.contains(entity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
        child: Row(children: [
          if (!metadata.hasTags) ...[
            Text('', style: Theme.of(context).textTheme.bodySmall,)
          ] else
            ...intersperse(Text(', ', style: Theme.of(context).textTheme.bodySmall),
                metadata.tags.map((e) => Text(e.tag, style: Theme.of(context).textTheme.bodySmall))).toList(),
          ...[
            const Spacer(),
            IconButton(
                icon: const Icon(Icons.edit),
                constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                iconSize: 12,
                padding: EdgeInsets.zero,
                splashRadius: 0.0001,
                tooltip: 'Provide comma separated list of Tags to edit...',
                onPressed: () => ref.read(metadataNotifierProvider(entity).notifier).setEditable(true)),
          ]
        ]));
  }
}