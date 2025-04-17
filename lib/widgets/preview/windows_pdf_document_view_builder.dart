import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class WindowsPdfDocumentViewBuilder extends StatefulWidget {
  const WindowsPdfDocumentViewBuilder({required this.documentRef, required this.builder, super.key});

  WindowsPdfDocumentViewBuilder.bytes(
      Uint8List bytes, {
        required String sourceName,
        required this.builder,
        super.key,
        PdfPasswordProvider? passwordProvider,
        bool firstAttemptByEmptyPassword = true,
        bool autoDispose = true,
      }) : documentRef = PdfDocumentRefData(
    bytes,
    sourceName: sourceName,
    passwordProvider: passwordProvider,
    firstAttemptByEmptyPassword: firstAttemptByEmptyPassword,
    autoDispose: autoDispose,
  );

  /// A reference to the PDF document.
  final PdfDocumentRef documentRef;

  /// A builder that builds a widget tree with the PDF document.
  final PdfDocumentViewBuilderFunction builder;

  @override
  State<WindowsPdfDocumentViewBuilder> createState() => _WindowsPdfDocumentViewBuilderState();

  static WindowsPdfDocumentViewBuilder? maybeOf(BuildContext context) {
    return context.findAncestorWidgetOfExactType<WindowsPdfDocumentViewBuilder>();
  }
}

class _WindowsPdfDocumentViewBuilderState extends State<WindowsPdfDocumentViewBuilder> {
  @override
  void initState() {
    super.initState();
    widget.documentRef.resolveListenable()
      ..addListener(_onDocumentChanged)
      ..load();
  }

  @override
  void dispose() {
    widget.documentRef.resolveListenable().removeListener(_onDocumentChanged);
    super.dispose();
  }

  void _onDocumentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final listenable = widget.documentRef.resolveListenable();
    return widget.builder(context, listenable.document);
  }
}
