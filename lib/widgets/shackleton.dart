import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../notifiers/folder.dart';
import 'filesystementity_preview.dart';
import 'folder_list.dart';

class Shackleton extends StatelessWidget {
  const Shackleton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    ScrollController scrollController = ScrollController();

    return Consumer<Folder>(builder: (context, model, child) {
      if (model.folderPaths.isEmpty) {
        model.setStartingFolder(Directory(_getHome()));
      }
      return Scaffold(
          appBar: AppBar(
            title: Text(model.folderPaths.map((e) => e.path.split('/').last).toString(), style: Theme.of(context).textTheme.labelSmall),
            actions: <Widget>[IconButton(icon: const Icon(Icons.preview_sharp), onPressed: () => model.togglePreview())],
          ),
          body: Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 6),
              child: Column(children: [
                if (model.showPreview) ... {
                  SizedBox(height: model.previewHeight, child: const FileSystemEntityPreview()),
                  MouseRegion(
                      cursor: SystemMouseCursors.resizeRow,
                      child: GestureDetector(
                        onVerticalDragUpdate: (DragUpdateDetails details) {
                          model.setPreviewHeight(details.delta.dy);
                        },
                        child: Container(color: const Color.fromRGBO(217, 217, 217, 100), height: 3),
                      )),
                },
                Expanded(child: Scrollbar(
                    thumbVisibility: true,
                    controller: scrollController,
                    child: ListView(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        children: model.folderPaths.map((e) => SizedBox(width: model.getSettings(e).width, child: FolderList(path: e))).toList())),
                )])));
    });
  }

  String _getHome() {
    return Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  }
}