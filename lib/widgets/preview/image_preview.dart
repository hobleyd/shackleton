import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/rotate_image_use_case.dart';
import '../../models/file_of_interest.dart';

class ImagePreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;
  final double previewWidth;

  const ImagePreview(
      {super.key,
      required this.entity,
      required this.isSelected,
      required this.previewWidth});

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreview();
}

class _ImagePreview extends ConsumerState<ImagePreview> {
  final _rotateUseCase = RotateImageUseCase();
  Uint8List? _rotatedBytes;
  bool _isRotatingImage = false;

  get entityPreview => widget.entity;
  get isSelected => widget.isSelected;
  get previewWidth => widget.previewWidth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            _getIconButton(Icons.rotate_left,
                height: 16,
                toolTip: 'Rotate left...',
                callback: () => _rotateLeft()),
            Expanded(
                child: Container(
                    alignment: Alignment.center,
                    child: Text(entityPreview.name,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall))),
            _getIconButton(Icons.rotate_right,
                height: 16,
                toolTip: 'Rotate Right...',
                callback: () => _rotateRight()),
          ],
        ),
        _isRotatingImage
            ? const Expanded(
                child: CircularProgressIndicator.adaptive(strokeWidth: 8))
            : Expanded(
                child: _rotatedBytes == null
                    ? Image.file(entityPreview.entity as File,
                        alignment: Alignment.center,
                        fit: BoxFit.contain,
                        width: previewWidth,
                        cacheWidth: (previewWidth *
                                MediaQuery.of(context).devicePixelRatio)
                            .round())
                    : Image.memory(_rotatedBytes!,
                        alignment: Alignment.center,
                        fit: BoxFit.contain,
                        width: previewWidth,
                        cacheWidth: (previewWidth *
                                MediaQuery.of(context).devicePixelRatio)
                            .round()),
              ),
      ],
    );
  }

  Widget _getIconButton(IconData iconData,
      {required String toolTip, required double height, VoidCallback? callback}) {
    return IconButton(
        icon: Icon(iconData),
        constraints: BoxConstraints(minHeight: height, maxHeight: height),
        iconSize: height,
        padding: EdgeInsets.zero,
        splashRadius: 0.0001,
        tooltip: toolTip,
        onPressed: callback);
  }

  void _rotateLeft() => _rotate(-90);
  void _rotateRight() => _rotate(90);

  void _rotate(int degrees) async {
    setState(() => _isRotatingImage = true);
    _rotatedBytes = await _rotateUseCase.execute(entityPreview, degrees);
    if (mounted) setState(() => _isRotatingImage = false);
  }
}
