import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/keyboard_callback.dart';
import '../interfaces/tag_handler.dart';
import '../misc/keyboard_handler.dart';
import '../models/file_of_interest.dart';
import '../models/tag.dart';
import '../providers/contents/pane_contents.dart';
import '../providers/contents/pane_tags.dart';
import '../providers/file_events.dart';
import '../providers/metadata.dart';
import 'entity_preview.dart';
import 'entity_context_menu.dart';
import 'metadata/metadata_editor.dart';

class PreviewPane extends ConsumerStatefulWidget {
  final FileOfInterest initialEntity;
  const PreviewPane({super.key, required this.initialEntity});

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPane();
}

class _PreviewPane extends ConsumerState<PreviewPane> implements KeyboardCallback, TagHandler {
  late List<FileOfInterest> entities;
  late PageController _controller;
  late KeyboardHandler handler;
  int _lastSelectedItemIndex = -1;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(paneContentsProvider);

    // First time through, we set the initial image to the one clicked on.
    if (_lastSelectedItemIndex == -1) {
      _lastSelectedItemIndex = entities.indexOf(widget.initialEntity);
      _controller = PageController(initialPage: _lastSelectedItemIndex);
    }

    if (_lastSelectedItemIndex == -1) {
      // This means that the initialEntry widget isn't in the list - because we deleted the file;
      // exit the build() in this case as it's a side effect of the Provider build from the file
      // delete. TODO: is there a better way to deal with this?
      exit();

      // Avoid a rebuild while we wait for the Context to pop.
      return const SizedBox.shrink();
    }

    return Scaffold(
        appBar: AppBar(
          elevation: 2,
          shadowColor: Theme.of(context).shadowColor,
          title: Text(entities.toString(), style: Theme.of(context).textTheme.labelSmall),
        ),
        body: Row(children: [
          Expanded(
            child: EntityContextMenu(
              child: MouseRegion(
                onEnter: (_) => handler.hasFocus = true,
                onExit: (_) => handler.hasFocus = false,
                child: _getPageView(),
              ),
            ),
          ),
          const VerticalDivider(),
          SizedBox(width: 210, child: MetadataEditor(keyHandlerCallback: this, tagHandler: this, paneEntity: entities[_lastSelectedItemIndex])),
        ]));
  }

  @override
  void dispose() {
    handler.deregister();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    Future(() {
      // Update the selected previewItem to show correct metadata
      ref.read(paneTagsProvider.notifier).replace(widget.initialEntity);
    });

    handler = KeyboardHandler(ref: ref, keyboardCallback: this);
    handler.register();
  }

  Widget _getPageView() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20),
      color: Colors.transparent,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (index) {
              _lastSelectedItemIndex = index;

              ref.read(paneTagsProvider.notifier).replace(entities[index]);
            },
            itemCount: entities.length,
            itemBuilder: (BuildContext context, int pos) {
              return EntityPreview(entity: entities[pos], isSelected: false, displayMetadata: false, previewWidth: MediaQuery.of(context).size.width - 210);
            },
          ),
          Align(
            alignment: Alignment.center,
            child: Row(
              children: [
                IconButton(
                    onPressed: () => left(),
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 28.0)),
                const Spacer(),
                IconButton(
                    onPressed: () => right(),
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 28.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void delete() {
    if (_lastSelectedItemIndex != -1) {
      var fileEvents = ref.read(fileEventsProvider.notifier);

      // Get the entity, reset the selected entity to the previous one, or exit if it was the last one. Then delete the file.
      final FileOfInterest entity = entities[_lastSelectedItemIndex];
      if (_lastSelectedItemIndex >= entities.length-1) {
        _lastSelectedItemIndex--;
      }

      if (_lastSelectedItemIndex == -1) {
        exit();
      }

      fileEvents.delete(entity, deleteEntity: true);
    }
  }

  @override
  void down() {
  }

  @override
  void exit() {
    Navigator.of(context, rootNavigator: true).maybePop(context);
  }

  @override
  void left() {
    if (_lastSelectedItemIndex != 0) {
      _controller.previousPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  @override
  void newEntity() {
  }

  @override
  void removeTag(Tag tag) {
    ref.read(metadataProvider(entities[_lastSelectedItemIndex]).notifier).removeTags(tag);
  }

  @override
  void right() {
    if (_lastSelectedItemIndex < entities.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  @override
  void up() {
  }

  @override
  void updateTags(String tags) {
    ref.read(metadataProvider(entities[_lastSelectedItemIndex]).notifier).updateTagsFromString(tags, updateFile: true);
    ref.read(paneTagsProvider.notifier).replace(entities[_lastSelectedItemIndex]);
  }

  @override
  void selectAll() {
  }
}
