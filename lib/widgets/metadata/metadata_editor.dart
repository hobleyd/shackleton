import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';
import '../../providers/selected_entities.dart';
import 'metadata_location.dart';

class MetadataEditor extends ConsumerStatefulWidget {
  final FileType completeListType;
  final FileType selectedListType;
  final KeyboardCallback callback;

  const MetadataEditor({Key? key, required this.completeListType, required this.selectedListType, required this.callback}) : super(key: key);

  @override
  ConsumerState<MetadataEditor> createState() => _MetadataEditor();
}

class _MetadataEditor extends ConsumerState<MetadataEditor> implements KeyboardCallback {
  late KeyboardHandler handler;
  late TextEditingController tagController;
  late FocusNode focusNode;

  get callback => widget.callback;
  get completeListType => widget.completeListType;
  get selectedListType => widget.selectedListType;

  // TODO: If I delete an image, the tags don't refresh on the image that replaces it!
  // TODO: Ctrl-A for files not visible breaks dragging due to list creation optimisation.

  @override
  Widget build(BuildContext context,) {
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesProvider(selectedListType));
    if (entities.isEmpty) {
      entities = ref.watch(selectedEntitiesProvider(completeListType));
    }

    final List<Tag> tags = [...{ for (var e in entities) ...ref.watch(metadataProvider(e)).tags }];

    return MouseRegion(
      onEnter: (_) => handler.hasFocus = true,
      onExit: (_) => handler.hasFocus = false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
        child: Column(
          children: [
            Text(
              'Metadata',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 10),
            Expanded(
                child: ListView.builder(
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      return Container(
                          color: index % 2 == 1 ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.white,
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Row(children: [
                            GestureDetector(
                              onTap: () => _filterByTag(ref, tags[index]),
                              child: Text(tags[index].tag, style: Theme.of(context).textTheme.bodySmall),
                            ),
                            const Spacer(),
                            IconButton(
                                icon: const Icon(Icons.clear),
                                constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                                iconSize: 12,
                                padding: EdgeInsets.zero,
                                splashRadius: 0.0001,
                                tooltip: 'Remove tag from selected images...',
                                onPressed: () => _removeTags(ref, entities, tags, index)),
                          ]));
                    })),
            const Spacer(),
            MetadataLocation(entities: entities,),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    autofocus: true,
                    controller: tagController,
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Add tags here', isDense: true),
                    focusNode: focusNode,
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
      ),
    );
  }

  @override
  void dispose() {
    handler.deregister();
    focusNode.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    tagController = TextEditingController();
    focusNode = FocusNode();

    handler = KeyboardHandler(ref: ref, keyboardCallback: this);
    handler.register();
  }

  void _filterByTag(WidgetRef ref, Tag tag) {
    Set<FileOfInterest> filteredEntities = {};

    Set<FileOfInterest> gridEntries = ref.watch(selectedEntitiesProvider(completeListType));
    for (var e in gridEntries) {
      FileMetaData meta = ref.watch(metadataProvider(e));
      if (meta.contains(tag)) {
        filteredEntities.add(e);
      }
    }

    var selectedList = ref.read(selectedEntitiesProvider(selectedListType).notifier);
    selectedList.replaceAll(filteredEntities);
  }

  void _removeTags(WidgetRef ref, Set<FileOfInterest> entities, List<Tag> tags, int index) {
    for (var e in entities) {
      ref.read(metadataProvider(e).notifier).removeTags(e, tags[index]);
    }
  }

  bool _updateTags(WidgetRef ref, Set<FileOfInterest> entities, String tags) {
    for (var e in entities) {
      ref.read(metadataProvider(e).notifier).updateTagsFromString(e, tags);
    }

    tagController.text = '';
    focusNode.requestFocus();

    return true;
  }

  @override
  void delete() {
    // I think that passing this back would result in people accidentally deleting files, so no.
    //if (tagController.text.isEmpty) callback.delete();
  }

  @override
  void left() {
    if (tagController.text.isEmpty) callback.left();
  }

  @override
  void right() {
    if (tagController.text.isEmpty) callback.right();
  }

  @override
  void exit() => callback.exit();

  @override
  void newEntity() {}

  @override
  void selectAll() {}
}
