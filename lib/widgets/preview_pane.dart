import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../interfaces/keyboard_callback.dart';
import '../misc/keyboard_handler.dart';
import '../models/file_of_interest.dart';
import '../providers/file_events.dart';
import '../providers/selected_entities.dart';
import 'entity_preview.dart';
import 'entity_context_menu.dart';
import 'metadata_editor.dart';

class PreviewPane extends ConsumerStatefulWidget {
  final FileOfInterest initialEntity;
  const PreviewPane({Key? key, required this.initialEntity}) : super(key: key);

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPane();
}

class _PreviewPane extends ConsumerState<PreviewPane> implements KeyboardCallback {
  late List<FileOfInterest> entities;
  late PageController _controller;
  late KeyboardHandler handler;
  int _lastSelectedItemIndex = -1;

  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> previewEntities = ref.watch(selectedEntitiesProvider(FileType.previewPane));
    entities = previewEntities.toList();
    entities.sort();

    // First time through, we set the initial image to the one clicked on.
    if (_lastSelectedItemIndex == -1) {
      _lastSelectedItemIndex = entities.indexOf(widget.initialEntity);
      _controller = PageController(initialPage: _lastSelectedItemIndex);
    }

    return Scaffold(
        appBar: AppBar(
          title: Text(entities.toString(), style: Theme.of(context).textTheme.labelSmall),
        ),
        body: Row(children: [
          Expanded(
            child: EntityContextMenu(
              fileType: FileType.previewPane,
              child: MouseRegion(
                onEnter: (_) => handler.hasFocus = true,
                onExit: (_) => handler.hasFocus = false,
                child: _getPageView(),
              ),
            ),
          ),
          const VerticalDivider(),
          SizedBox(width: 200, child: MetadataEditor(completeListType: FileType.previewPane, selectedListType: FileType.previewItem, callback: this,)),
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
      ref.read(selectedEntitiesProvider(FileType.previewItem).notifier).replace(widget.initialEntity);
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

              ref.read(selectedEntitiesProvider(FileType.previewItem).notifier).replace(entities[index]);
            },
            itemCount: entities.length,
            itemBuilder: (BuildContext context, int pos) {
              return EntityPreview(entity: entities[pos], isSelected: false, displayMetadata: false,);
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

      if (_lastSelectedItemIndex == entities.length) {
        _lastSelectedItemIndex--;
      }
      fileEvents.delete(entities[_lastSelectedItemIndex]);
      if (ref.watch(selectedEntitiesProvider(FileType.previewPane)).isEmpty) {
        exit();
      }
    }
  }

  @override
  void exit() {
    ref.read(selectedEntitiesProvider(FileType.previewPane).notifier).removeAll();
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
  void right() {
    if (_lastSelectedItemIndex < entities.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 100), curve: Curves.easeIn);
    }
  }

  @override
  void selectAll() {
  }
}
