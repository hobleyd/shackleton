import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/file_of_interest.dart';
import '../providers/selected_entities.dart';
import 'preview_grid.dart';

class PreviewPane extends ConsumerWidget {
  const PreviewPane({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesProvider(FileType.previewGrid));

    return Scaffold(
        appBar: AppBar(
          title: Text(entities.toString(), style: Theme
              .of(context)
              .textTheme
              .labelSmall),
        ),
        body: const PreviewGrid(columnCount: 1, type: FileType.previewGrid));
  }
}