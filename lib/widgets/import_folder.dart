import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/widgets/folder_list.dart';

import '../models/file_of_interest.dart';
import '../providers/folder_contents.dart';

class ImportFolder extends ConsumerStatefulWidget {
  final Set<FileOfInterest> folders;
  const ImportFolder({Key? key, required this.folders}) : super(key: key);

  @override
  ConsumerState<ImportFolder> createState() => _ImportFolder();
}

class _ImportFolder extends ConsumerState<ImportFolder> {
  late List<FileOfInterest> entities;

  Directory get folder => widget.folders.first.entity as Directory;

  @override
  Widget build(BuildContext context) {
    entities = ref.watch(folderContentsProvider(folder));

    return Scaffold(
      appBar: AppBar(
        title: Text(entities.toString(), style: Theme.of(context).textTheme.labelSmall),
      ),
      body: FolderList(path: folder),
    );
  }
}