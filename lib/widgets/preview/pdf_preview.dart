import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../models/file_of_interest.dart';
import 'windows_pdf_document_view_builder.dart';

class PDFPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;
  final bool showFullFile;

  const PDFPreview({super.key, required this.entity, required this.isSelected, required this.showFullFile,});

  @override
  ConsumerState<PDFPreview> createState() => _PDFPreview();
}

class _PDFPreview extends ConsumerState<PDFPreview> {
  get entityPreview => widget.entity;
  get isSelected    => widget.isSelected;
  get showFullFile => widget.showFullFile;

  late Uint8List windowsPDFData;

  @override
  Widget build(BuildContext context) {
    final Color background = isSelected ? Theme.of(context).textSelectionTheme.selectionHandleColor! : Colors.transparent;

    if (Platform.isWindows) {
      // Windows locks the file if we open it in the PDFViewer constructor, so we need to load the data into memory on Windows...
      // I can't believe Windows still locks files exclusively. It's not the 90's any more Microsoft.
      windowsPDFData = entityPreview.entity.readAsBytesSync();
    }

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
            child: Platform.isWindows
                ? showFullFile
                    ? PdfViewer.data(windowsPDFData, sourceName: entityPreview.name)
                    : WindowsPdfDocumentViewBuilder.bytes(
                        windowsPDFData,
                        sourceName: entityPreview.name,
                        builder: (context, document) => ListView.builder(
                          itemCount: 1,
                          itemBuilder: (context, index) {
                            return PdfPageView(
                              document: document,
                              pageNumber: 1,
                              alignment: Alignment.center,
                            );
                          },
                        ),
                      )
                : showFullFile
                    ? PdfViewer.file(entityPreview.path)
                    : PdfDocumentViewBuilder.file(
                        entityPreview.path,
                        builder: (context, document) => ListView.builder(
                          itemCount: 1,
                          itemBuilder: (context, index) {
                            return PdfPageView(
                              document: document,
                              pageNumber: 1,
                              alignment: Alignment.center,
                            );
                          },
                        ),
              ),
          ),
        ),
      ],
    );
  }
}
