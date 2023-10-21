import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:intersperse/intersperse.dart';
import 'package:shackleton/widgets/video_player.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/file_of_interest.dart';
import '../models/file_metadata.dart';
import '../providers/metadata.dart';
import '../providers/selected_entities.dart';

class EntityPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final FileType selectionType;
  final bool displayMetadata;

  const EntityPreview({Key? key, required this.entity, required this.selectionType, this.displayMetadata = true}) : super(key: key);

  @override
  ConsumerState<EntityPreview> createState() => _EntityPreview();
}

class _EntityPreview extends ConsumerState<EntityPreview> {
  late Set<FileOfInterest> selectedEntities;
  late FileMetaData metadata;
  late Widget _imagePreview;
  late Color _background;

  bool _isRotatingImage = false;
  Uint8List? _rotatedBytes;

  get displayMetaData => widget.displayMetadata;
  get selectedEntity  => widget.entity;
  get selectionType   => widget.selectionType;

  @override
  Widget build(BuildContext context) {
    selectedEntities = ref.watch(selectedEntitiesProvider(selectionType));
    metadata = ref.watch(metadataProvider(selectedEntity));

    _imagePreview = selectedEntity.canPreview ? _getPreview() : Expanded(child: Text(selectedEntity.name));

    _background = (selectionType != FileType.previewItem && selectedEntities.contains(selectedEntity))
        ? Theme.of(context).textSelectionTheme.selectionHandleColor!
        : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            if (selectedEntity.isImage) _getIconButton(Icons.rotate_left, height: 16, toolTip: 'Rotate left...', callback: () => _rotateLeft()),
            Expanded(child: Container(alignment: Alignment.center, child: Text(selectedEntity.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall,))),
            if (selectedEntity.isImage) _getIconButton(Icons.rotate_right, height: 16, toolTip: 'Rotate Right...', callback: () => _rotateRight()),
          ],
        ),
        _isRotatingImage
            ? const Expanded(child: CircularProgressIndicator.adaptive(strokeWidth: 8,))
            : Expanded(child: Container(alignment: Alignment.center, color: _background, padding: const EdgeInsets.symmetric(vertical: 10), child: _imagePreview)),
        if (displayMetaData) ...[
          SizedBox(height: 5, child: Container(color: _background)),
          metadata.isEditing ? _getEditableMetadata(context, ref) : _getMetadata(context, ref),
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

  Widget _getMetadata(BuildContext context, WidgetRef ref) {
    return Container(
        padding: const EdgeInsets.only(left: 2),
        color: selectedEntities.contains(selectedEntity) ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
        child: Row(children: [
          Expanded(child: _getMetadataText()),
          const SizedBox(width: 3),
          IconButton(
              icon: const Icon(Icons.edit),
              constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
              iconSize: 12,
              padding: EdgeInsets.zero,
              splashRadius: 0.0001,
              tooltip: 'Edit comma separated list of Tags...',
              onPressed: () => ref.read(metadataProvider(selectedEntity).notifier).setEditable(true)),
        ]
        ));
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
      return SfPdfViewer.file(selectedEntity.entity as File);
    }

    if (selectedEntity.isVideo) {
      return ShackletonVideoPlayer(path: selectedEntity.path);
    }

    if (_rotatedBytes != null) {
      return Image.memory(_rotatedBytes!, alignment: Alignment.center, fit: BoxFit.contain);
    }
    return Image.file(selectedEntity.entity as File, alignment: Alignment.center, fit: BoxFit.contain);
  }

  bool _replaceTags(WidgetRef ref, String tags) {
    ref.read(metadataProvider(selectedEntity).notifier).replaceTagsFromString(selectedEntity, tags);

    return true;
  }

  void _rotate(int degrees) async {
    setState(() {
      _isRotatingImage = true;
    });

    File imageFile = selectedEntity.entity as File;
    Uint8List originalBytes = await imageFile.readAsBytes();
    img.Image decodedImage  = img.decodeImage(originalBytes)!;
    img.Image rotatedImage  = img.copyRotate(decodedImage, angle: degrees);
    _rotatedBytes  = switch (selectedEntity.extension) {
      'jpg' || 'jpeg' => img.encodeJpg(rotatedImage),
      'png'           => img.encodePng(rotatedImage),
      'tiff'          => img.encodeTiff(rotatedImage),
      'gif'           => img.encodeGif(rotatedImage),
      _               => originalBytes,
    };
    await imageFile.writeAsBytes(_rotatedBytes!);
    await ref.read(metadataProvider(selectedEntity).notifier).saveMetadata(selectedEntity, metadata.tags);

    setState(() {
      _isRotatingImage = false;
    });
  }

  void _rotateLeft() async {
    _rotate(-90);
  }

  void _rotateRight() async {
    _rotate(90);
  }
}