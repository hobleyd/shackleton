import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/contents/folder_contents.dart';

class FolderColumnHeaders extends ConsumerWidget {
  final Directory path;
  final bool showDetailedView;

  const FolderColumnHeaders({super.key, required this.path, required this.showDetailedView});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
     var entitiesNotifier = ref.read(folderContentsProvider(path).notifier);

      Widget sortIcon = entitiesNotifier.getSortOrder() == EntitySortOrder.asc ? const Icon(Icons.expand_less) : const Icon(Icons.expand_more);

      return Row(children: [
        Expanded(
          child: TextButton.icon(
            onPressed: () => entitiesNotifier.sortBy(EntitySortField.name),
            icon: entitiesNotifier.getSortField() == EntitySortField.name ? sortIcon : const Icon(Icons.remove),
            label: Text('Name', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
          ),
        ),
        if (showDetailedView) ...[
          SizedBox(
            width: 80,
            child: TextButton.icon(
              onPressed: () => entitiesNotifier.sortBy(EntitySortField.size),
              icon: entitiesNotifier.getSortField() == EntitySortField.size ? sortIcon : const Icon(Icons.remove),
              label: Text('Size', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: TextButton.icon(
              onPressed: () => entitiesNotifier.sortBy(EntitySortField.modified),
              icon: entitiesNotifier.getSortField() == EntitySortField.modified ? sortIcon : const Icon(Icons.remove),
              label: Text('Modified', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
        ],
      ]);
    }
  }