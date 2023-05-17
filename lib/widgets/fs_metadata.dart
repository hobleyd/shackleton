import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifiers/file_cache.dart';

class FileSystemEntityMetadata extends StatelessWidget {
  FileSystemEntity entity;

  FileSystemEntityMetadata({Key? key, required this.entity}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<FileCache>(builder: (context, model, child) {
      model.loadMetadata(entity);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.file(File.fromUri(entity.uri), fit: BoxFit.fitHeight),
          const SizedBox(height: 10),
          if (model.metadata[entity.path] == null || model.metadata[entity.path]!.isEmpty)
            Text('No metadata found for this image.', style: Theme.of(context).textTheme.bodySmall,)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: model.metadata[entity.path]!.map((e) => Text(e, style: Theme.of(context).textTheme.bodySmall)).toList(),
            ),
        ],
      );
    });
  }
}