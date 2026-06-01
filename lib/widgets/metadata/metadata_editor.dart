import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../interfaces/tag_handler.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/contents/grid_tags.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/pane_tags.dart';
import '../../repositories/file_tags_repository.dart';
import 'metadata_location.dart';

class MetadataEditor extends ConsumerStatefulWidget {
  final KeyboardCallback keyHandlerCallback;
  final FileOfInterest? paneEntity;
  final TagHandler tagHandler;

  const MetadataEditor({super.key, required this.keyHandlerCallback, required this.tagHandler, this.paneEntity, });

  @override
  ConsumerState<MetadataEditor> createState() => _MetadataEditor();
}

class _MetadataEditor extends ConsumerState<MetadataEditor> {
  late TextEditingController tagController;
  late FocusNode focusNode;

  get keyHandlerCallback => widget.keyHandlerCallback;
  get tagHandler => widget.tagHandler;
  get paneEntity => widget.paneEntity;

  @override
  Widget build(BuildContext context,) {
    final List<Tag> tags = paneEntity == null ? ref.watch(gridTagsProvider) : ref.watch(paneTagsProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 10),
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
                      padding: const EdgeInsets.only(right: 10),
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
                  autofocus: false,
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
    );
  }

  @override
  void dispose() {
    focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    tagController = TextEditingController();
    focusNode = FocusNode();
    focusNode.unfocus();

    focusNode.onKeyEvent = (node, event) {
      if (event is! KeyDownEvent) return KeyEventResult.ignored;

      if (tagController.text.isEmpty) {
        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
          keyHandlerCallback.left();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
          keyHandlerCallback.right();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
          keyHandlerCallback.up();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
          keyHandlerCallback.down();
          return KeyEventResult.handled;
        } else if (event.logicalKey == LogicalKeyboardKey.escape) {
          keyHandlerCallback.exit();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        keyHandlerCallback.exit();
        return KeyEventResult.handled;
      }

      return KeyEventResult.ignored;
    };
  }

  Future<void> _filterByTag(WidgetRef ref, Tag tag) async {
    final repo = ref.read(fileTagsRepositoryProvider.notifier);

    // Prefetch all metadata for this tag in one JOIN query so EntityPreview
    // widgets don't each fire individual DB queries when the grid renders.
    await repo.prefetchMetadataForTag(tag);

    final taggedFiles = await repo.getFilesForTag(tag);
    final taggedPaths = {for (final f in taggedFiles) f.path};

    final gridEntries = ref.read(gridContentsProvider);
    final filtered = gridEntries.where((e) => taggedPaths.contains(e.path)).toSet();

    if (!const DeepCollectionEquality.unordered().equals(gridEntries, filtered)) {
      ref.read(gridContentsProvider.notifier).replaceAll(filtered);
    }
  }

  void _removeTag(WidgetRef ref, Tag tag) {
    tagHandler.removeTag(tag);
  }

  bool _updateTags(WidgetRef ref, String tags) {
    tagHandler.updateTags(tags);

    tagController.text = '';
    focusNode.requestFocus();

    return true;
  }
}
