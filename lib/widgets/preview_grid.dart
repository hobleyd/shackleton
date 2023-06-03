import 'package:Shackleton/models/file_of_interest.dart';
import 'package:Shackleton/providers/selected_entities.dart';
import 'package:Shackleton/widgets/metadata_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

import 'entity_preview.dart';

class PreviewGrid extends ConsumerWidget {
  const PreviewGrid({Key? key}) : super(key: key);

  // TODO: Add buttons to rotate the selected image(s)
  // TODO: Add key navigation
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesProvider(FileType.folderList));
    List<FileOfInterest> entities = selectedEntities.toList();
    entities.sort();

    return selectedEntities.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Text(
              'Select one or more files to preview!',
              textAlign: TextAlign.center,
            ))
        : Row(children: [
            Expanded(
              child: ContextMenuWidget(
                child: GridView.count(
                    primary: false,
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    crossAxisCount: 5,
                    children: entities
                        .map((e) => GestureDetector(onTap: () => _selectEntity(ref, e), onDoubleTap: () => e.openFile(), child: EntityPreview(entity: e)))
                        .toList()),
                menuProvider: (_) {
                  var selectedPreviewEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
                  return Menu(children: [
                    MenuAction(
                      callback: () => selectedPreviewEntities.clear(),
                      image: MenuImage.icon(Icons.deselect),
                      title: 'Deselect all',
                    ),
                    if (ref.watch(selectedEntitiesProvider(FileType.previewGrid)).isNotEmpty) ...[
                      MenuSeparator(),
                      MenuAction(
                        attributes: const MenuActionAttributes(destructive: true),
                        image: MenuImage.icon(Icons.delete),
                        callback: () => selectedPreviewEntities.deleteFiles(),
                        title: 'Delete selected files',
                      ),
                    ]
                  ]);
                },
              ),
            ),
            const SizedBox(width: 200, child: MetadataEditor()),
          ]);
  }

  void _selectEntity(WidgetRef ref, FileOfInterest entity) {
    var selectedEntities = ref.read(selectedEntitiesProvider(FileType.previewGrid).notifier);
    selectedEntities.contains(entity) ? selectedEntities.remove(entity) : selectedEntities.add(entity);
  }
}