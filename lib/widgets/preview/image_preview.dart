import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../../models/file_of_interest.dart';
import '../../providers/metadata.dart';

class ImagePreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;

  const ImagePreview({Key? key, required this.entity, required this.isSelected,}) : super(key: key);

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreview();
}

class _ImagePreview extends ConsumerState<ImagePreview> {
  Uint8List? _rotatedBytes;
  bool _isRotatingImage = false;

  get entityPreview => widget.entity;
  get isSelected    => widget.isSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            _getIconButton(Icons.rotate_left, height: 16, toolTip: 'Rotate left...', callback: () => _rotateLeft()),
            Expanded(child: Container(alignment: Alignment.center, child: Text(entityPreview.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall,))),
            _getIconButton(Icons.rotate_right, height: 16, toolTip: 'Rotate Right...', callback: () => _rotateRight()),
          ],
        ),
        _isRotatingImage
            ? const Expanded(child: CircularProgressIndicator.adaptive(strokeWidth: 8,))
            : Expanded(
                child: Container(
                  alignment: Alignment.center,
                  color: isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: _rotatedBytes == null
                      ? Image.file(entityPreview.entity as File, alignment: Alignment.center, fit: BoxFit.contain)
                      : Image.memory(_rotatedBytes!, alignment: Alignment.center, fit: BoxFit.contain),
                ),
              ),
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

  void _rotate(int degrees) async {
    setState(() {
      _isRotatingImage = true;
    });

    File imageFile = entityPreview.entity as File;
    Uint8List originalBytes = await imageFile.readAsBytes();
    img.Image decodedImage  = img.decodeImage(originalBytes)!;
    img.Image rotatedImage  = img.copyRotate(decodedImage, angle: degrees);
    _rotatedBytes  = switch (entityPreview.extension) {
    'jpg' || 'jpeg' => img.encodeJpg(rotatedImage),
    'png'           => img.encodePng(rotatedImage),
    'tif' || 'tiff' => img.encodeTiff(rotatedImage),
    'gif'           => img.encodeGif(rotatedImage),
    _               => originalBytes,
    };
    await imageFile.writeAsBytes(_rotatedBytes!);

    var metadata = ref.read(metadataProvider(entityPreview).notifier);
    await metadata.saveMetadata(updateFile: true);

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