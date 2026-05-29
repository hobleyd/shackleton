import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';

import '../../models/file_of_interest.dart';
import '../../models/file_metadata.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/metadata.dart';
import '../metadata/fix_metadata.dart';
import '../preview/image_preview.dart';
import '../preview/markdown_preview.dart';
import '../preview/pdf_preview.dart';
import '../preview/video_preview.dart';

class EntityPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool displayMetadata;
  final double previewWidth;

  const EntityPreview({super.key, required this.entity, required this.previewWidth, this.displayMetadata = true});

  @override
  ConsumerState<EntityPreview> createState() => _EntityPreview();
}

class _EntityPreview extends ConsumerState<EntityPreview> {
  late FileMetaData metadata;

  bool get displayMetaData => widget.displayMetadata;
  FileOfInterest get selectedEntity => widget.entity;
  double get previewWidth => widget.previewWidth;

  @override
  Widget build(BuildContext context) {
    metadata = ref.watch(metadataProvider(selectedEntity));
    final isSelected = ref.watch(
      selectedGridPathsProvider.select((paths) => paths.contains(selectedEntity.path)),
    );
    final background = isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        selectedEntity.canPreview
            ? Expanded(
                child: Container(
                  alignment: Alignment.center,
                  color: background,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _getPreview(isSelected),
                ),
              )
            : Expanded(
                child: Text(selectedEntity.name),
              ),
        if (displayMetaData) ...[
          SizedBox(height: 5, child: Container(color: background)),
          _getMetadata(context, ref, isSelected),
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _getIconButton(IconData iconData, { required String toolTip, required double height, VoidCallback? callback}) {
    return IconButton(
        icon: Icon(iconData),
        constraints: BoxConstraints(minHeight: height, maxHeight: height),
        iconSize: height,
        padding: EdgeInsets.zero,
        splashRadius: 0.0001,
        tooltip: toolTip,
        onPressed: callback);
  }

  Widget _getMetadata(BuildContext context, WidgetRef ref, bool isSelected) {
    final background = isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;
    return Container(
        padding: const EdgeInsets.only(left: 2),
        color: metadata.corruptedMetadata ? Colors.red : background,
        child: Row(children: [
          Expanded(child: _getMetadataText()),
          if (metadata.corruptedMetadata) ...[
            const SizedBox(width: 3),
            _getIconButton(Icons.auto_fix_high,
                height: 12,
                toolTip: 'Fix metadata in file...',
                callback: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FixMetadata(file: selectedEntity))))
          ],
        ]));
  }

  Widget _getMetadataText() {
    if (!metadata.hasTags) {
      return Text('', style: Theme.of(context).textTheme.bodySmall,);
    } else {
      List<String> tags = intersperse(', ', metadata.tags.map((e) => e.tag)).toList();
      String tagsString = '';
      for (var t in tags) {
        tagsString += t;
      }
      return Text(tagsString, maxLines: 2, style: Theme.of(context).textTheme.bodySmall,);
    }
  }

  Widget _getPreview(bool isSelected) {
    return switch (selectedEntity.extension) {
      'pdf'                                           => PDFPreview(entity: selectedEntity, isSelected: isSelected, showFullFile: !displayMetaData),
      'md'                                            => MarkdownPreview(entity: selectedEntity, isSelected: isSelected),
      (String ext) when videoExtensions.contains(ext) => VideoPreview(entity: selectedEntity, isSelected: isSelected),
      _                                               => ImagePreview(entity: selectedEntity, isSelected: isSelected, previewWidth: previewWidth, enableZoomPan: !displayMetaData),
    };
  }
}