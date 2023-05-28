import 'package:Shackleton/models/file_of_interest.dart';
import 'package:Shackleton/models/metadata.dart';
import 'package:Shackleton/providers/selected_entities_notifier.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tag.dart';
import '../providers/metadata_notifier.dart';

class MetadataEditor extends ConsumerWidget {
  const MetadataEditor({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    TextEditingController tagController = TextEditingController();

    // TODO: Display list of Tags to (optionally delete).
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesNotifierProvider);
    final List<Tag> tags = {for (var e in entities) ...ref.watch(metadataNotifierProvider(e.entity)).tags}.toList();

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
      child: Column(
        children: [
          Expanded(
              child: ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (context, index) {
                    return Row(children: [
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
                                ref.read(metadataNotifierProvider(e.entity).notifier).removeTags(tags[index]);
                              })),
                    ]);
                  })),
          const Spacer(),
          Row(
            children: [
              Expanded(
                  child: TextField(
                decoration: const InputDecoration(border: InputBorder.none),
                autofocus: true,
                controller: tagController,
                keyboardType: TextInputType.multiline,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall,
              )),
              IconButton(
                  icon: const Icon(Icons.add),
                  constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                  iconSize: 12,
                  padding: EdgeInsets.zero,
                  splashRadius: 0.0001,
                  tooltip: 'Add tags to selected images...',
                  onPressed: () => entities.forEach((e) {
                        ref.read(metadataNotifierProvider(e.entity).notifier).saveTags(tagController.text);
                      })),
            ],
          ),
        ],
      ),
    );
    // TODO: Then an editable Textbox to add more entries.
  }
}
