import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../interfaces/tag_handler.dart';
import '../../models/file_of_interest.dart';
import '../../models/map_settings.dart';
import '../../models/tag.dart';
import '../../providers/map_pane.dart';
import '../../providers/metadata.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../entity_context_menu.dart';
import '../metadata/metadata_editor.dart';
import 'grid_controller.dart';
import 'photo_map.dart';
import 'shackleton_grid_view.dart';

class PreviewGrid extends ConsumerStatefulWidget {
  const PreviewGrid({super.key});

  @override
  ConsumerState<PreviewGrid> createState() => _PreviewGrid();
}

class _PreviewGrid extends ConsumerState<PreviewGrid> implements TagHandler{
  late List<FileOfInterest> entities;
  late GridController gridController;

  @override
  Widget build(BuildContext context) {
    MapSettings map = ref.watch(mapPaneProvider);
    entities = ref.watch(gridContentsProvider);

    return entities.isEmpty
        ? Padding(
            padding: const EdgeInsets.only(top: 50),
            child: Text(entities.isNotEmpty ? 'Your selected files are not previewable (yet), sorry' : 'Select one or more files to preview!', textAlign: TextAlign.center,))
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
            SizedBox(width: 210, child: MetadataEditor(keyHandlerCallback: gridController, tagHandler: this)),
          ]);
  }

  @override
  void dispose() {
    gridController.deregister();

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
