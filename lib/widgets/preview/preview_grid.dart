import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/tag_handler.dart';
import '../../models/file_of_interest.dart';
import '../../models/map_settings.dart';
import '../../models/tag.dart';
import '../../providers/face_recognition_provider.dart';
import '../../providers/map_pane.dart';
import '../../providers/metadata.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../entity_context_menu.dart';
import '../face_recognition/face_search_panel.dart';
import '../metadata/metadata_editor.dart';
import '../slideshow/slideshow_panel.dart';
import 'grid_controller.dart';
import 'photo_map.dart';
import 'shackleton_grid_view.dart';

enum _RightPanel { metadata, faceSearch, slideshow }

class PreviewGrid extends ConsumerStatefulWidget {
  const PreviewGrid({super.key});

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> implements TagHandler {
  late List<FileOfInterest> entities;
  late GridController gridController;
  _RightPanel _rightPanel = _RightPanel.metadata;

  @override
  Widget build(BuildContext context) {
    MapSettings map = ref.watch(mapPaneProvider);
    entities = ref.watch(gridContentsProvider);

    ref.listen<FaceSearchState>(faceSearchProvider, (prev, next) {
      if (next.status == FaceSearchStatus.done && next.results.isNotEmpty) {
        ref.read(gridContentsProvider.notifier).replaceAll(
              next.results.map((r) => r.file).toSet(),
            );
      } else if (next.status == FaceSearchStatus.idle &&
          prev != null &&
          prev.status == FaceSearchStatus.done) {
        // Only restore the grid when the user resets after a completed search
        // (done → idle). Transitioning from detecting/scanning → idle should
        // not disturb the current grid contents.
        ref.invalidate(gridContentsProvider);
      }
    });

    return entities.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text(
              entities.isNotEmpty
                  ? 'Your selected files are not previewable (yet), sorry'
                  : 'Select one or more files to preview!',
              textAlign: TextAlign.center,
            ))
        : Row(children: [
            Expanded(
              child: EntityContextMenu(
                child: ShackletonGridView(gridController: gridController),
              ),
            ),
            if (map.visible) ...[
              MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  onHorizontalDragUpdate: (DragUpdateDetails details) {
                    ref.read(mapPaneProvider.notifier).changeWidth(details.delta.dx);
                  },
                  child: Container(color: const Color.fromRGBO(217, 217, 217, 100), width: 3),
                ),
              ),
              SizedBox(width: map.width, child: const PhotoMap()),
            ],
            const VerticalDivider(),
            SizedBox(
              width: 210,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: _rightPanel == _RightPanel.faceSearch
                            ? 'Back to metadata'
                            : 'Face search',
                        child: IconButton(
                          iconSize: 16,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _rightPanel == _RightPanel.faceSearch
                                ? Icons.edit_note
                                : Icons.face_retouching_natural,
                          ),
                          onPressed: () => setState(() => _rightPanel =
                              _rightPanel == _RightPanel.faceSearch
                                  ? _RightPanel.metadata
                                  : _RightPanel.faceSearch),
                        ),
                      ),
                      Tooltip(
                        message: _rightPanel == _RightPanel.slideshow
                            ? 'Back to metadata'
                            : 'Create slideshow',
                        child: IconButton(
                          iconSize: 16,
                          padding: const EdgeInsets.all(4),
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            _rightPanel == _RightPanel.slideshow
                                ? Icons.edit_note
                                : Icons.slideshow,
                          ),
                          onPressed: () => setState(() => _rightPanel =
                              _rightPanel == _RightPanel.slideshow
                                  ? _RightPanel.metadata
                                  : _RightPanel.slideshow),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: switch (_rightPanel) {
                      _RightPanel.faceSearch => const FaceSearchPanel(),
                      _RightPanel.slideshow => const SlideshowPanel(),
                      _RightPanel.metadata => MetadataEditor(
                          keyHandlerCallback: gridController,
                          tagHandler: this,
                        ),
                    },
                  ),
                ],
              ),
            ),
          ]);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    gridController = GridController(context: context, ref: ref);
  }

  @override
  void removeTag(Tag tag) {
    List<FileOfInterest> selectedEntities = ref.read(selectedGridEntitiesProvider);

    for (var e in selectedEntities) {
      ref.read(metadataProvider(e).notifier).removeTags(tag);
    }
  }

  @override
  void updateTags(String tags) {
    List<FileOfInterest> selectedEntities = ref.read(selectedGridEntitiesProvider);

    for (var e in selectedEntities) {
      ref.read(metadataProvider(e).notifier).updateTagsFromString(tags);
    }
  }
}
