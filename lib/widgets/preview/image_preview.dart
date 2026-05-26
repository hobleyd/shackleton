import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/use_cases/rotate_image_use_case.dart';
import '../../models/file_of_interest.dart';
import '../../providers/exif_tool_service_provider.dart';

class ImagePreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;
  final double previewWidth;
  // When true the widget is in the grid view: load a small embedded thumbnail
  // instead of the full-resolution image.
  final bool showThumbnail;

  const ImagePreview({
    super.key,
    required this.entity,
    required this.isSelected,
    required this.previewWidth,
    this.showThumbnail = false,
  });

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreview();
}

class _ImagePreview extends ConsumerState<ImagePreview> {
  final _rotateUseCase = RotateImageUseCase();
  Uint8List? _rotatedBytes;
  Uint8List? _thumbnailBytes;
  bool _thumbnailLoading = false;
  bool _isRotatingImage = false;

  FileOfInterest get entityPreview => widget.entity;
  bool get isSelected => widget.isSelected;
  double get previewWidth => widget.previewWidth;

  @override
  void initState() {
    super.initState();
    if (widget.showThumbnail) _loadThumbnail();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity.path != widget.entity.path && widget.showThumbnail) {
      setState(() {
        _thumbnailBytes = null;
        _thumbnailLoading = false;
      });
      _loadThumbnail();
    }
  }

  Future<void> _loadThumbnail() async {
    setState(() => _thumbnailLoading = true);
    final service = ref.read(exifToolServiceProvider);
    final bytes = await service.readThumbnail(entityPreview.path);
    if (mounted) setState(() { _thumbnailBytes = bytes; _thumbnailLoading = false; });
  }

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
        if (_isRotatingImage)
          const Expanded(child: CircularProgressIndicator.adaptive(strokeWidth: 8))
        else
          Expanded(child: _buildImage(context)),
      ],
    );
  }

  Widget _buildImage(BuildContext context) {
    // Rotated state always wins.
    if (_rotatedBytes != null) {
      return Image.memory(_rotatedBytes!,
          alignment: Alignment.center,
          fit: BoxFit.contain,
          width: previewWidth,
          cacheWidth: _cacheWidth(context));
    }

    // Grid view: prefer the small embedded thumbnail; fall back to full image.
    if (widget.showThumbnail) {
      if (_thumbnailLoading) {
        return const Center(child: CircularProgressIndicator.adaptive(strokeWidth: 2));
      }
      if (_thumbnailBytes != null) {
        return Image.memory(_thumbnailBytes!,
            alignment: Alignment.center,
            fit: BoxFit.contain,
            width: previewWidth);
      }
      // No embedded thumbnail — fall through to full image below.
    }

    return Image.file(entityPreview.entity as File,
        alignment: Alignment.center,
        fit: BoxFit.contain,
        width: previewWidth,
        cacheWidth: _cacheWidth(context));
  }

  int _cacheWidth(BuildContext context) =>
      (previewWidth * MediaQuery.of(context).devicePixelRatio).round();

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
