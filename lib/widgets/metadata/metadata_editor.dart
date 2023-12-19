import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';
import '../../providers/selected_entities/selected_entities.dart';
import '../../providers/selected_entities/selected_tags.dart';
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
  Timer? _debounce;

  get callback => widget.callback;
  get completeListType => widget.completeListType;
  get selectedListType => widget.selectedListType;

  @override
  Widget build(BuildContext context,) {
    final List<Tag> tags = ref.watch(selectedTagsProvider(selectedListType, completeListType));

    return MouseRegion(
      onEnter: (_) => handler.hasFocus = true,
      onExit: (_) => handler.hasFocus = false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
        child: Column(
          children: [
            Text('Metadata', style: Theme.of(context).textTheme.labelSmall,),
            const SizedBox(height: 10),
            Expanded(
                child: ListView.builder(
                    itemCount: tags.length,
                    itemBuilder: (context, index) {
                      return Container(
                        color: index % 2 == 1 ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.white,
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _filterByTag(ref, tags[index]),
                              child: Text(tags[index].tag, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                            ),
                          ),
                          const SizedBox(width: 5),
                          IconButton(
                              icon: const Icon(Icons.clear),
                              constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                              iconSize: 12,
                              padding: EdgeInsets.zero,
                              splashRadius: 0.0001,
                              tooltip: 'Remove tag from selected images...',
                              onPressed: () => _removeTags(ref, tags, index)),
                        ]),
                      );
                    })),
            const Spacer(),
            MetadataLocation(selectedListType: selectedListType, completeListType: completeListType,),
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
                    onSubmitted: (tags) => _updateTags(ref, tags),
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
                    onPressed: () => _updateTags(ref, tagController.text)),
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

  Set<FileOfInterest> _getSelectedEntities() {
    Set<FileOfInterest> entities = ref.read(selectedEntitiesProvider(selectedListType));
    if (entities.isEmpty) {
      entities = ref.read(selectedEntitiesProvider(completeListType));
    }

    return entities;
  }

  void _removeTags(WidgetRef ref, List<Tag> tags, int index) {
    Set<FileOfInterest> entities = _getSelectedEntities();

    for (var e in entities) {
      ref.read(metadataProvider(e).notifier).removeTags(tags[index]);
    }
  }

  bool _updateTags(WidgetRef ref, String tags) {
    Set<FileOfInterest> entities = _getSelectedEntities();

    for (var e in entities) {
      ref.read(metadataProvider(e).notifier).updateTagsFromString(tags);
    }

    tagController.text = '';
    focusNode.requestFocus();

    return true;
  }

  @override
  void delete() {
    // We want to be able to delete files in the PreviewPane, we also want to be able to edit Metadata in the same Pane; what we don't want to
    // happen is for people to delete text from the Metadata Text editor and accidentally delete files with an overloaded delete key. So, put
    // a delay in so that we can't delete without purpose. Any UX people willing to pitch in for a better solution would be greatly appreciated.
    if (tagController.text.isNotEmpty) {
      if (_debounce?.isActive ?? false) _debounce?.cancel();

      _debounce = Timer(const Duration(milliseconds: 4000), () {});
    }

    if (_debounce?.isActive ?? false) {
      return;
    } else {
      if (tagController.text.isEmpty) callback.delete();
    }
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
