import 'package:Shackleton/models/file_of_interest.dart';
import 'package:Shackleton/providers/selected_entities_notifier.dart';
import 'package:Shackleton/widgets/metadata_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'filesystem_entity_metadata.dart';

class FileSystemEntityPreview extends ConsumerWidget {
  const FileSystemEntityPreview({Key? key}) : super(key: key);

  // TODO: Add buttons to rotate the selected image(s)
  // TODO: Add key navigation
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Set<FileOfInterest> selectedEntities = ref.watch(selectedEntitiesNotifierProvider);

    return selectedEntities.isEmpty
        ? const Padding(
            padding: EdgeInsets.only(top: 50),
            child: Text(
              'Select one or more files to preview!',
              textAlign: TextAlign.center,
            ))
        : Row(children: [
            Expanded(
                child: GridView.count(
                    primary: false,
                    padding: const EdgeInsets.only(left: 20, right: 20),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    crossAxisCount: 5,
                    children: selectedEntities
                        .map((e) => GestureDetector(
                            onTap: () => selectedEntities.contains(e) ? selectedEntities.remove(e) : selectedEntities.add(e),
                            onDoubleTap: () => e.openFile(),
                            child: FileSystemEntityMetadata(entity: e)))
                        .toList())),
            const SizedBox(width: 200, child: MetadataEditor()),
          ]);
  }
}