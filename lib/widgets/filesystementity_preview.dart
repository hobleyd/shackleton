import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifiers/folder.dart';
import 'fs_metadata.dart';

class FileSystemEntityPreview extends StatelessWidget {
  const FileSystemEntityPreview({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<Folder>(builder: (context, model, child) {
      return model.selectedEntities.isEmpty
          ? const Padding(
              padding: EdgeInsets.only(top: 50),
              child: Text(
                'Select one or more files to preview!',
                textAlign: TextAlign.center,
              ))
          : GridView.count(
                  primary: false,
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  crossAxisCount: 5,
                  children: model.selectedEntities
                      .map((e) => FileSystemEntityMetadata(entity: e))
                      .toList());
    });
  }
}