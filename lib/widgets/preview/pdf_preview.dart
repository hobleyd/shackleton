import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/file_of_interest.dart';
import '../../providers/selected_entities.dart';

class PDFPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;

  const PDFPreview({super.key, required this.entity, required this.isSelected,});

  @override
  ConsumerState<PDFPreview> createState() => _PDFPreview();
}

class _PDFPreview extends ConsumerState<PDFPreview> {
  get entityPreview => widget.entity;
  get isSelected    => widget.isSelected;

  @override
  Widget build(BuildContext context) {
    final Color background = isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.max,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.center,
                color: background,
                child: Text(entityPreview.name, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelSmall,),
              ),
            ),
          ],
        ),
        Expanded(
          child: Container(
            alignment: Alignment.center,
            color: background,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: SfPdfViewer.file(entityPreview.entity as File),
          ),
        ),
      ],
    );
  }
}
