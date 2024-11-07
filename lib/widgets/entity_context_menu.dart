import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_context_menu/super_context_menu.dart';

import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../providers/file_events.dart';
import '../providers/folder_path.dart';
import '../providers/contents/selected_grid_entities.dart';

class EntityContextMenu extends ConsumerWidget {
  final Widget child;
  final FileOfInterest? folder;

  const EntityContextMenu({super.key, required this.child, this.folder});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContextMenuWidget(
      child: child,
      menuProvider: (_) {
        var selectedGridEntities = ref.read(selectedGridEntitiesProvider.notifier);
        var entities = ref.watch(selectedGridEntitiesProvider);
        return Menu(children: [
          MenuAction(
            callback: () => selectedGridEntities.clear(),
            image: MenuImage.icon(Icons.deselect),
            title: 'Deselect all',
          ),
          MenuAction(
            callback: () => createZip(folder ?? FileOfInterest(entity: ref.read(folderPathProvider).first), entities.toSet()),
            image: MenuImage.icon(Icons.archive_outlined),
            title: 'Create (Zip) Archive',
          ),
          if (entities.isNotEmpty) ...[
            MenuSeparator(),
            MenuAction(
              attributes: const MenuActionAttributes(destructive: true),
              image: MenuImage.icon(Icons.delete),
              callback: () => ref.read(fileEventsProvider.notifier).deleteAll(entities.toSet()),
              title: 'Delete selected files',
            ),
          ]
        ]);
      },
    );
  }
}