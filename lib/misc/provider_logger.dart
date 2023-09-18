import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shackleton/providers/selected_entities.dart';

var logger = Logger();

class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container,) {
    if (provider.name == 'selectedEntitiesProvider') {
      //debugPrint('[${provider.name ?? provider.runtimeType}] value: $newValue');
      debugPrint('selectedEntitiesProvider(FolderList): ${container.read(selectedEntitiesProvider(FileType.folderList))}');
      debugPrint('selectedEntitiesProvider(PreviewGrid): ${container.read(selectedEntitiesProvider(FileType.previewGrid))}');
      //logger.d('PreviewGrid: ${container.read(selectedEntitiesProvider(FileType.previewGrid))}');
    }
  }
}
