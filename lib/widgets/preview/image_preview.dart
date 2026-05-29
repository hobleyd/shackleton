import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

import '../../application/use_cases/rotate_image_use_case.dart';
import '../../models/file_of_interest.dart';

class ImagePreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;
  final double previewWidth;
  final bool enableZoomPan;

  const ImagePreview({
    super.key,
    required this.entity,
    required this.isSelected,
    required this.previewWidth,
    this.enableZoomPan = false,
  });

  @override
  ConsumerState<ImagePreview> createState() => _ImagePreview();
}

class _ImagePreview extends ConsumerState<ImagePreview> {
  final _rotateUseCase = RotateImageUseCase();
  Uint8List? _editedBytes;
  bool _isRotatingImage = false;
  late TransformationController _transformController;
  bool _isZoomed = false;

  static const double _minScale = 1.0;
  static const double _maxScale = 8.0;

  FileOfInterest get entityPreview => widget.entity;
  double get previewWidth => widget.previewWidth;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _transformController.addListener(_onTransformChanged);
  }

  @override
  void dispose() {
    _transformController.removeListener(_onTransformChanged);
    _transformController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.entity != widget.entity) {
      _transformController.value = Matrix4.identity();
    }
  }

  void _onTransformChanged() {
    final scale = _transformController.value.storage[0];
    final isZoomed = scale > 1.01;
    if (isZoomed != _isZoomed) {
      setState(() => _isZoomed = isZoomed);
    }
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (!HardwareKeyboard.instance.isControlPressed) return;
    _handleZoom(event);
  }

  void _handleZoom(PointerScrollEvent event) {
    final scaleFactor = event.scrollDelta.dy < 0 ? 1.1 : 0.9;
    final m = _transformController.value;
    final currentScale = m.storage[0];
    final newScale = (currentScale * scaleFactor).clamp(_minScale, _maxScale);

    if ((newScale - currentScale).abs() < 1e-4) return;

    if (newScale <= _minScale + 1e-4) {
      _transformController.value = Matrix4.identity();
      return;
    }

    final ratio = newScale / currentScale;
    final tx = m.storage[12];
    final ty = m.storage[13];
    final fx = event.localPosition.dx;
    final fy = event.localPosition.dy;

    final newMatrix = Matrix4.identity();
    newMatrix.storage[0] = newScale;
    newMatrix.storage[5] = newScale;
    newMatrix.storage[12] = fx - ratio * (fx - tx);
    newMatrix.storage[13] = fy - ratio * (fy - ty);
    _transformController.value = newMatrix;
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
            _getIconButton(Icons.edit,
                height: 16,
                toolTip: 'Edit image...',
                callback: () => _openEditor(context)),
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
    final image = _editedBytes != null
        ? Image.memory(_editedBytes!,
            alignment: Alignment.center,
            fit: BoxFit.contain,
            width: previewWidth,
            cacheWidth: _cacheWidth(context))
        : Image.file(entityPreview.entity as File,
            alignment: Alignment.center,
            fit: BoxFit.contain,
            width: previewWidth,
            cacheWidth: _cacheWidth(context));

    if (!widget.enableZoomPan) return image;

    return Listener(
      onPointerSignal: _onPointerSignal,
      child: InteractiveViewer(
        transformationController: _transformController,
        panEnabled: _isZoomed,
        scaleEnabled: false,
        minScale: _minScale,
        maxScale: _maxScale,
        child: SizedBox.expand(child: image),
      ),
    );
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
    _editedBytes = await _rotateUseCase.execute(entityPreview, degrees);
    if (mounted) setState(() => _isRotatingImage = false);
  }

  Future<void> _openEditor(BuildContext context) async {
    final sourceBytes = _editedBytes ?? await (entityPreview.entity as File).readAsBytes();

    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProImageEditor.memory(
          sourceBytes,
          callbacks: ProImageEditorCallbacks(
            onImageEditingComplete: (Uint8List editedBytes) async {
              await (entityPreview.entity as File).writeAsBytes(editedBytes);
              if (mounted) setState(() => _editedBytes = editedBytes);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }
}
