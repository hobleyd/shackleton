import 'package:file_icon/file_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../misc/keyboard_handler.dart';
import '../../misc/utils.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/folder_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';

class EntityRow extends ConsumerWidget {
  final FileOfInterest entity;
  final bool showDetailedView;
  final KeyboardHandler handler;

  const EntityRow({super.key, required this.entity, required this.showDetailedView, required this.handler});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TextEditingController tagController = TextEditingController();
    tagController.text = entity.name;
    tagController.selection = TextSelection(baseOffset: 0, extentOffset: entity.extensionIndex);

    return Row(
      children: [
        FileIcon(entity.path),
        if (entity.editing) ...[
          Expanded(
            child: TextField(
                autofocus: true,
                controller: tagController,
                decoration: const InputDecoration(border: InputBorder.none, isDense: true,),
                keyboardType: TextInputType.text,
                maxLines: 1,
                onSubmitted: (tags) => _renameFile(ref, entity, tagController.text),
                style: Theme
                    .of(context)
                    .textTheme
                    .bodySmall),
          ),
          IconButton(
              icon: const Icon(Icons.save),
              constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
              iconSize: 12,
              padding: EdgeInsets.zero,
              splashRadius: 0.0001,
              tooltip: 'Rename file...',
              onPressed: () => _renameFile(ref, entity, tagController.text)),
        ],
        if (!entity.editing) ...[
          Expanded(
            child: Text(entity.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme
                .of(context)
                .textTheme
                .bodySmall),
          ),
        ],
        if (showDetailedView) ...[
          SizedBox(width: 40, child: Text(getEntitySizeString(entity: entity, decimals: 0), textAlign: TextAlign.right, style: Theme
              .of(context)
              .textTheme
              .bodySmall),),
          const SizedBox(width: 10),
          SizedBox(width: 120, child: Text(DateFormat('dd MMM yyyy HH:mm').format(entity.stat.modified), style: Theme
              .of(context)
              .textTheme
              .bodySmall, textAlign: TextAlign.right),),
        ],
        const SizedBox(width: 10),
      ],
    );
  }

  void _renameFile(WidgetRef ref, FileOfInterest entity, String filename) {
    FolderContents contents = ref.read(folderContentsProvider(entity.entity.parent).notifier);
    contents.setEditableState(entity, false);
    handler.setEditing(false);

    FileOfInterest newEntity = entity.rename(filename);
    ref.read(selectedFolderContentsProvider.notifier).replace(newEntity);
  }
}