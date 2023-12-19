import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/selected_entities/selected_entities.dart';

import '../models/file_of_interest.dart';
import '../models/import_entity.dart';
import '../providers/import.dart';

class ImportFolder extends ConsumerStatefulWidget {
  const ImportFolder({Key? key,}) : super(key: key);

  @override
  ConsumerState<ImportFolder> createState() => _ImportFolder();
}

class _ImportFolder extends ConsumerState<ImportFolder> {
  bool isImporting = false;

  @override
  Widget build(BuildContext context) {
    Set<FileOfInterest> entities = ref.watch(selectedEntitiesProvider(FileType.folderList));

    return Scaffold(
        appBar: AppBar(
          elevation: 2,
          shadowColor: Theme.of(context).shadowColor,
          title: Text('Import files to Library', style: Theme.of(context).textTheme.labelSmall),
        ),
        body: Consumer(
          builder: (context, watch, child) {
            var importAsync = ref.watch(importProvider(entities));
            return importAsync.when(error: (error, stackTrace) {
              return Text('$error', style: Theme.of(context).textTheme.bodySmall);
            }, loading: () {
              return const Center(heightFactor: 1.0, child: CircularProgressIndicator());
            }, data: (List<ImportEntity> filesToImport) {
              return Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 10.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text('Files to Import...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                            ),
                            const SizedBox(width: 48),
                            Expanded(
                              child: Text('Files after Import...', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(width: 10.0),
                              Expanded(child: _getFilesToImportList(filesToImport)),
                              const SizedBox(width: 48),
                              Expanded(child: _getRenamedFilesList(filesToImport)),
                              const SizedBox(width: 10.0),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  Center(
                    child: isImporting
                    ? const CircularProgressIndicator()
                    : IconButton(
                      constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
                      iconSize: 48,
                      onPressed: () => _moveFiles(filesToImport),
                      padding: const EdgeInsets.only(top: 5),
                      splashRadius: 0.0001,
                      tooltip: 'Import files',
                      icon: const Icon(Icons.arrow_circle_right_outlined),
                    ),
                  ),
                ],
              );
            });
          },
        ));
  }

  Widget _getFilesToImportList(List<ImportEntity> filesToImport) {
    return ListView.builder(
            itemCount: filesToImport.length,
            itemBuilder: (context, index) {
              ImportEntity entity = filesToImport[index];
              TextEditingController source = TextEditingController();
              source.text = entity.fileToImport.path;
              return InkWell(
                  onTap: () => {},
                  onDoubleTap: () => {},
                  child: Container(
                    color: entity.willImport ? Colors.lime : Colors.redAccent,
                    padding: const EdgeInsets.only(left: 5.0),
                    child: TextField(
                        autofocus: true,
                        controller: source,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.text,
                        maxLines: 1,
                        readOnly: true,
                        style: Theme.of(context).textTheme.bodySmall),
                  ));
            },
            physics: const NeverScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            shrinkWrap: true);
  }

  Widget _getRenamedFilesList(List<ImportEntity> filesToImport) {
    return ListView.builder(
        itemCount: filesToImport.length,
        itemBuilder: (context, index) {
          ImportEntity entity = filesToImport[index];
          TextEditingController dest = TextEditingController();
          dest.text = entity.error.isNotEmpty ? entity.error : entity.renamedFile;
          return InkWell(
            onTap: () => {},
            onDoubleTap: () => {},
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    color: entity.hasConflict || !entity.willImport ? Colors.redAccent : Colors.lime,
                    padding: const EdgeInsets.only(left: 5.0),
                    child: TextField(
                        autofocus: true,
                        controller: dest,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        keyboardType: TextInputType.text,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
                if (entity.hasConflict) ...[
                  IconButton(
                    icon: const Icon(Icons.done),
                    constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                    iconSize: 12,
                    padding: EdgeInsets.zero,
                    splashRadius: 0.0001,
                    tooltip: 'Ignore conflict and copy file...',
                    onPressed: () => setState(() {
                      filesToImport[index] = entity.copyWith(hasConflict: false, willImport: true);
                    }),
                  ),
                ],
              ],
            ),
          );
        },
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.vertical,
        shrinkWrap: true);
  }

  void _moveFiles(List<ImportEntity> entities) {
    setState(() {
      isImporting = true;
    });

    // Copy the list or we'll have a modification exception while looping...
    List<ImportEntity> entitiesToProcess = List.from(entities);
    for (var entity in entitiesToProcess) {
      try {
        if (entity.willImport) {
          entity.fileToImport.moveFile(entity.renamedFile);
          setState(() {
            entities.remove(entity);
          });
        }
      } on Exception catch (e) {
        // Not sure what Exceptions file operations can throw. Improve your documentation, please.
        setState(() {
          entities[entities.indexOf(entity)] = entity.copyWith(error: e.toString());
        });
      }
    }

    setState(() {
      isImporting = false;
    });
  }
}