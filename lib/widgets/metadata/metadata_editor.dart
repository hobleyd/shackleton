import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../interfaces/tag_handler.dart';
import '../../misc/keyboard_handler.dart';
import '../../models/file_metadata.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/metadata.dart';
import '../../providers/contents/grid_tags.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/pane_tags.dart';
import 'metadata_location.dart';

class MetadataEditor extends ConsumerStatefulWidget {
  final KeyboardCallback keyHandlerCallback;
  final FileOfInterest? paneEntity;
  final TagHandler tagHandler;

  const MetadataEditor({super.key, required this.keyHandlerCallback, required this.tagHandler, this.paneEntity, });

  @override
  ConsumerState<MetadataEditor> createState() => _MetadataEditor();
}

class _MetadataEditor extends ConsumerState<MetadataEditor> implements KeyboardCallback {
  late TextEditingController tagController;
  late KeyboardHandler handler;
  late FocusNode focusNode;

  get keyHandlerCallback => widget.keyHandlerCallback;
  get tagHandler => widget.tagHandler;
  get paneEntity => widget.paneEntity;

  @override
  Widget build(BuildContext context,) {
    final List<Tag> tags = paneEntity == null ? ref.watch(gridTagsProvider) : ref.watch(paneTagsProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
      child: MouseRegion(
        onEnter: (_) {
          handler.hasFocus = tagController.text.isEmpty;
        },
        onExit: (_) {
          handler.hasFocus = false;
          focusNode.unfocus();
        },
        child: Column(
          children: [
            Text(
              'Metadata',
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 10),
            Expanded(
                child: tags.isNotEmpty
                    ? ListView.builder(
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
                                  onPressed: () => _removeTag(ref, tags[index])),
                            ]),
                          );
                        })
                    : Center(child: Text('No tags for selected image(s)', style: Theme.of(context).textTheme.bodySmall))),
            const SizedBox(height: 10),
            MetadataLocation(paneEntity: widget.paneEntity),
            const SizedBox(height: 20),
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
                    onChanged: (text) {
                      handler.hasFocus = text.isEmpty;
                    },
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

    handler = KeyboardHandler(ref: ref, keyboardCallback: this, name: 'MetadataEditor');
    handler.processModifierKeys = false;
    handler.hasFocus = false;
    handler.register();
  }

  void _filterByTag(WidgetRef ref, Tag tag) {
    Set<FileOfInterest> filteredEntities = {};

    List<FileOfInterest> gridEntries = ref.watch(gridContentsProvider);
    for (var e in gridEntries) {
      FileMetaData meta = ref.watch(metadataProvider(e));
      if (meta.contains(tag)) {
        filteredEntities.add(e);
      }
    }

    if (!const DeepCollectionEquality.unordered().equals(gridEntries, filteredEntities)) {
      var selectedList = ref.read(gridContentsProvider.notifier);
      selectedList.replaceAll(filteredEntities);
    }
  }

  void _removeTag(WidgetRef ref, Tag tag) {
    tagHandler.removeTag(tag);
  }

  bool _updateTags(WidgetRef ref, String tags) {
    tagHandler.updateTags(tags);

    tagController.text = '';
    handler.hasFocus = true;
    focusNode.requestFocus();

    return true;
  }

  @override
  void delete() {
    // This doesn't work reliably and I keep deleting files I don't want to. So let's drop this for now and if the MetadataEditor has focus, we
    // won't ever delete a file.

    // We want to be able to delete files in the PreviewPane, we also want to be able to edit Metadata in the same Pane; what we don't want to
    // happen is for people to delete text from the Metadata Text editor and accidentally delete files with an overloaded delete key. So, put
    // a delay in so that we can't delete without purpose. Any UX people willing to pitch in for a better solution would be greatly appreciated.
    // if (tagController.text.isNotEmpty) {
    //   if (_debounce?.isActive ?? false) _debounce?.cancel();
    //
    //   _debounce = Timer(const Duration(milliseconds: 4000), () {});
    // }
    //
    // if (_debounce?.isActive ?? false) {
    //   return;
    // } else {
    //   if (tagController.text.isEmpty) keyHandlerCallback.delete();
    // }
  }

  @override
  void left() {
    if (tagController.text.isEmpty) keyHandlerCallback.left();
  }

  @override
  void right() {
    if (tagController.text.isEmpty) keyHandlerCallback.right();
  }

  @override
  void up() {
    if (tagController.text.isEmpty) keyHandlerCallback.up();
  }

  @override
  void down() {
    if (tagController.text.isEmpty) keyHandlerCallback.down();
  }

  @override
  void exit() => keyHandlerCallback.exit();

  @override
  void newEntity() {}

  @override
  void selectAll() {}
}
