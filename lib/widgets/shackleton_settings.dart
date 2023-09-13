import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/models/app_settings.dart';
import 'package:shackleton/repositories/app_settings_repository.dart';

class ShackletonSettings extends ConsumerWidget {
  final TextEditingController fontSizeController = TextEditingController();
  final TextEditingController libraryFolderController = TextEditingController();

  ShackletonSettings({Key? key,}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var appSettingsRepository = ref.read(appSettingsRepositoryProvider.notifier);

    // Pictures Folder
    // Font Size
    // Clear DB Cache
    // DB Statistics
    return Consumer(builder: (context, watch, child) {
      var appSettings = ref.watch(appSettingsRepositoryProvider);
      return appSettings.when(error: (error, stackTrace) {
        return Text('Failed to get settings.', style: Theme.of(context).textTheme.bodySmall);
      }, loading: () {
        return const CircularProgressIndicator();
      }, data: (AppSettings appSettings) {
        libraryFolderController.text = appSettings.libraryPath;
        fontSizeController.text = '${appSettings.fontSize}';
        return Scaffold(
          appBar: AppBar(
            title: Text('Settings', style: Theme.of(context).textTheme.labelSmall),
          ),
          body: Padding(
            padding: const EdgeInsets.all(6.0),
            child: SizedBox(
              width: 500,
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 120, child: Text('Library folder: ', style: Theme.of(context).textTheme.labelSmall)),
                      const SizedBox(width: 15),
                      SizedBox(
                        width: 300,
                        child: TextField(
                            autofocus: true,
                            controller: libraryFolderController,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            keyboardType: TextInputType.text,
                            maxLines: 1,
                            onSubmitted: (path) => appSettingsRepository.updateSettings(appSettings.copyWith(libraryPath: path)),
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(width: 120, child: Text('Font Size: ', style: Theme
                          .of(context)
                          .textTheme
                          .labelSmall)),
                      const SizedBox(width: 15),
                      IconButton(
                        icon: const Icon(Icons.remove),
                        constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                        iconSize: 12,
                        padding: EdgeInsets.zero,
                        splashRadius: 0.0001,
                        tooltip: 'Decrease font size...',
                        onPressed: () => _changeFontSize(appSettingsRepository, appSettings, -1),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 30,
                        child: TextField(
                          controller: fontSizeController,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.text,
                          maxLines: 1,
                          onSubmitted: (_) => _changeFontSize(appSettingsRepository, appSettings, 0),
                          style: Theme
                              .of(context)
                              .textTheme
                              .bodySmall,
                          textAlign: TextAlign.center,),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.add),
                        constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                        iconSize: 12,
                        padding: EdgeInsets.zero,
                        splashRadius: 0.0001,
                        tooltip: 'Increase font size...',
                        onPressed: () => _changeFontSize(appSettingsRepository, appSettings, 1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      );
    });
  }

  bool _changeFontSize(var appSettingsRepository, AppSettings appSettings, int delta) {
    int? size = int.tryParse(fontSizeController.text);
    if (size == null) {
      return false;
    }
    size += delta;

    appSettingsRepository.updateSettings(appSettings.copyWith(fontSize: size));
    return true;
  }
}