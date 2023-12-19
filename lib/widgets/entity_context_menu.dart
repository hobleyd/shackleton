import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../providers/file_events.dart';
import '../providers/folder_path.dart';
import '../providers/selected_entities/selected_entities.dart';

class EntityContextMenu extends ConsumerWidget {
  final Widget child;
  final FileType fileType;
  final FileOfInterest? folder;

  const EntityContextMenu({Key? key, required this.child, required this.fileType, this.folder}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuWidget(
      child: child,
      menuProvider: (_) {
        var selectedPreviewEntities = ref.read(selectedEntitiesProvider(fileType).notifier);
        var entities = ref.watch(selectedEntitiesProvider(fileType));
        return Menu(children: [
          MenuAction(
            callback: () => selectedPreviewEntities.clear(),
            image: MenuImage.icon(Icons.deselect),
            title: 'Deselect all',
          ),
          MenuAction(
            callback: () => createZip(folder ?? FileOfInterest(entity: ref.read(folderPathProvider).first), entities),
            image: MenuImage.icon(Icons.archive_outlined),
            title: 'Create (Zip) Archive',
          ),
          if (ref.watch(selectedEntitiesProvider(fileType)).isNotEmpty) ...[
            MenuSeparator(),
            MenuAction(
              attributes: const MenuActionAttributes(destructive: true),
              image: MenuImage.icon(Icons.delete),
              callback: () => ref.read(fileEventsProvider.notifier).deleteAll(entities),
              title: 'Delete selected files',
            ),
          ]
        ]);
      },
    );
  }
}