import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/keyboard_callback.dart';
import '../../interfaces/tag_handler.dart';
import '../../misc/app_intents.dart';
import '../../models/file_of_interest.dart';
import '../../models/tag.dart';
import '../../providers/contents/pane_contents.dart';
import '../../providers/contents/pane_tags.dart';
import '../../providers/file_events.dart';
import '../../providers/metadata.dart';
import 'entity_preview.dart';
import '../entity_context_menu.dart';
import '../metadata/metadata_editor.dart';

class PreviewPane extends ConsumerStatefulWidget {
  final FileOfInterest initialEntity;
  const PreviewPane({super.key, required this.initialEntity});

  @override
  ConsumerState<PreviewPane> createState() => _PreviewPane();
}

class _PreviewPane extends ConsumerState<PreviewPane> implements KeyboardCallback, TagHandler {
  late List<FileOfInterest> entities;
  late PageController _controller;
  final FocusNode _focusNode = FocusNode();
  int _lastSelectedItemIndex = -1;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(paneContentsProvider);

    if (_lastSelectedItemIndex == -1) {
      _lastSelectedItemIndex = entities.indexOf(widget.initialEntity);
      _controller = PageController(initialPage: _lastSelectedItemIndex);
    }
    if (_lastSelectedItemIndex == -1) {
      exit();
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
              child: Shortcuts(
                shortcuts: {
                  const SingleActivator(LogicalKeyboardKey.arrowLeft): const NavigateLeftIntent(),
                  const SingleActivator(LogicalKeyboardKey.arrowRight): const NavigateRightIntent(),
                  // Space is intercepted here so PageView's Scrollable handler never sees it,
                  // preventing the duplicate KeyDownEvent assertion on macOS desktop.
                  const SingleActivator(LogicalKeyboardKey.space): const NavigateRightIntent(),
                  const SingleActivator(LogicalKeyboardKey.backspace): const DeleteIntent(),
                  const SingleActivator(LogicalKeyboardKey.delete): const DeleteIntent(),
                  const SingleActivator(LogicalKeyboardKey.escape): const ExitIntent(),
                },
                child: Actions(
                  actions: {
                    NavigateLeftIntent: CallbackAction<NavigateLeftIntent>(onInvoke: (_) => left()),
                    NavigateRightIntent: CallbackAction<NavigateRightIntent>(onInvoke: (_) => right()),
                    DeleteIntent: CallbackAction<DeleteIntent>(onInvoke: (_) => delete()),
                    ExitIntent: CallbackAction<ExitIntent>(onInvoke: (_) => exit()),
                  },
                  child: MouseRegion(
                    onEnter: (_) => _focusNode.requestFocus(),
                    child: Focus(
                      focusNode: _focusNode,
                      child: _getPageView(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const VerticalDivider(),
          SizedBox(width: 210, child: MetadataEditor(keyHandlerCallback: this, tagHandler: this, paneEntity: entities[_lastSelectedItemIndex])),
        ]));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    Future(() {
      ref.read(paneTagsProvider.notifier).replace(widget.initialEntity);
    });
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
              return EntityPreview(entity: entities[pos], displayMetadata: false, previewWidth: MediaQuery.of(context).size.width - 210);
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
    _lastSelectedItemIndex = -1;
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
    ref.read(paneTagsProvider.notifier).replace(entities[_lastSelectedItemIndex]);
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
