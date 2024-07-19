import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intersperse/intersperse.dart';

import '../models/file_of_interest.dart';
import '../models/file_metadata.dart';
import '../providers/metadata.dart';
import 'metadata/fix_metadata.dart';
import 'preview/image_preview.dart';
import 'preview/pdf_preview.dart';
import 'preview/video_preview.dart';

class EntityPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;
  final bool displayMetadata;
  final double previewWidth;

  const EntityPreview({super.key, required this.entity, required this.isSelected, required this.previewWidth, this.displayMetadata = true});

  @override
  ConsumerState<EntityPreview> createState() => _EntityPreview();
}

class _EntityPreview extends ConsumerState<EntityPreview> {
  late FileMetaData metadata;

  get displayMetaData => widget.displayMetadata;
  get selectedEntity  => widget.entity;
  get isSelected      => widget.isSelected;
  get previewWidth    => widget.previewWidth;
  get background      => isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;

  @override
  Widget build(BuildContext context) {
    metadata = ref.watch(metadataProvider(selectedEntity));

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
                  child: _getPreview(),
                ),
              )
            : Expanded(
                child: Text(selectedEntity.name),
              ),
        if (displayMetaData) ...[
          SizedBox(height: 5, child: Container(color: background)),
          metadata.isEditing ? _getEditableMetadata(context, ref) : _getMetadata(context, ref, isSelected),
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
  }

  Widget _getEditableMetadata(BuildContext context, WidgetRef ref) {
    TextEditingController tagController = TextEditingController();

    if (metadata.tags.isNotEmpty) {
      for (int i = 0; i < metadata.tags.length; i++) {
        tagController.text += metadata.tags[i].tag;
        if (i != metadata.tags.length - 1) {
          tagController.text += ', ';
        }
      }
    }

    return Row(children: [
      Expanded(
        child: TextField(
            autofocus: true,
            controller: tagController,
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
            keyboardType: TextInputType.text,
            maxLines: 1,
            onSubmitted: (tags) => _replaceTags(ref, tags),
            style: Theme.of(context).textTheme.bodySmall),
      ),
      _getIconButton(
          Icons.save,
          height: 12,
          toolTip: 'Save comma separated list of Tags to file...',
          callback: () => _replaceTags(ref, tagController.text)),
    ]);
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
    return Container(
        padding: const EdgeInsets.only(left: 2),
        color: metadata.corruptedMetadata ? Colors.red : background,
        child: Row(children: [
          Expanded(child: _getMetadataText()),
          const SizedBox(width: 3),
          metadata.corruptedMetadata
              ? _getIconButton(Icons.auto_fix_high,
              height: 12, toolTip: 'Fix metadata in file...', callback: () => Navigator.push(context, MaterialPageRoute(builder: (context) => FixMetadata(file: selectedEntity))))
              : _getIconButton(Icons.edit,
              height: 12, toolTip: 'Edit comma separated list of Tags...', callback: () => ref.read(metadataProvider(selectedEntity).notifier).setEditable(true)),
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

  Widget _getPreview() {
    if (selectedEntity.extension == 'pdf') {
      return PDFPreview(entity: selectedEntity, isSelected: isSelected);
    }

    if (selectedEntity.isVideo) {
      return VideoPreview(entity: selectedEntity, isSelected: isSelected);
    }

    return ImagePreview(entity: selectedEntity, isSelected: isSelected, previewWidth: previewWidth);
  }

  bool _replaceTags(WidgetRef ref, String tags) {
    ref.read(metadataProvider(selectedEntity).notifier).replaceTagsFromString(tags);

    return true;
  }
}