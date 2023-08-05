import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_of_interest.dart';
import '../models/tag.dart';
import '../providers/metadata.dart';
import '../providers/selected_entities.dart';

class MetadataEditor extends ConsumerWidget {
  const MetadataEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TextEditingController tagController = TextEditingController();

    Set<FileOfInterest> previewSelectedEntities = ref.watch(selectedEntitiesProvider(FileType.previewGrid));
    Set<FileOfInterest> folderSelectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));
    Set<FileOfInterest> entities = previewSelectedEntities.isNotEmpty ? previewSelectedEntities : folderSelectedEntities;

    final List<Tag> tags = {for (var e in entities) ...ref.watch(metadataProvider(e)).tags}.toList();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
      child: Column(
        children: [
          Expanded(
              child: ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    return Container(
                        color: index % 2 == 1 ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.white,
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(children: [
                          Text(tags[index].tag, style: Theme.of(context).textTheme.bodySmall),
                          const Spacer(),
                          IconButton(
                              icon: const Icon(Icons.clear),
                              constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                              iconSize: 12,
                              padding: EdgeInsets.zero,
                              splashRadius: 0.0001,
                              tooltip: 'Remove tag from selected images...',
                              onPressed: () => entities.forEach((e) {
                                    ref.read(metadataProvider(e).notifier).removeTags(e, tags[index]);
                                  })),
                        ]));
                  })),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  autofocus: true,
                  controller: tagController,
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                  keyboardType: TextInputType.text,
                  maxLines: 1,
                  onSubmitted: (tags) => _updateTags(ref, entities, tags),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.add),
                  constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                  iconSize: 12,
                  padding: EdgeInsets.zero,
                  splashRadius: 0.0001,
                  tooltip: 'Add tags to selected images...',
                  onPressed: () => _updateTags(ref, entities, tagController.text)),
            ],
          ),
        ],
      ),
    );
  }

  bool _updateTags(WidgetRef ref, Set<FileOfInterest> entities, String tags) {
    for (var e in entities) {
      ref.read(metadataProvider(e).notifier).updateTagsFromString(e, tags);
    }

    return true;
  }
}
