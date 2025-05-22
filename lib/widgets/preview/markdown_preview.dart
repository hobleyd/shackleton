import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../../models/file_of_interest.dart';

class MarkdownPreview extends ConsumerStatefulWidget {
  final FileOfInterest entity;
  final bool isSelected;

  const MarkdownPreview({super.key, required this.entity, required this.isSelected,});

  @override
  ConsumerState<MarkdownPreview> createState() => _MarkdownPreview();
}

class _MarkdownPreview extends ConsumerState<MarkdownPreview> {
  ScrollController _scrollController = ScrollController();

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
            child: SingleChildScrollView(
              controller: _scrollController,
              scrollDirection: Axis.vertical,
              child: GptMarkdown((entityPreview.entity as File).readAsStringSync()),
            ),
          ),
        ),
      ],
    );
  }
}
