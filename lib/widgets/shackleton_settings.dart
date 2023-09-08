import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shackleton/providers/settings.dart';

class ShackletonSettings extends ConsumerWidget {
  const ShackletonSettings({Key? key,}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var settings = ref.watch(settingsProvider);

    TextEditingController fontSizeController = TextEditingController();
    TextEditingController libraryFolderController = TextEditingController();
    libraryFolderController.text = settings.libraryPath;
    fontSizeController.text = settings.fontSize.toString();

    // Pictures Folder
    // Font Size
    // Clear DB Cache
    // DB Statistics
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
                        onSubmitted: (tags) {},
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 120, child: Text('Font Size: ', style: Theme.of(context).textTheme.labelSmall)),
                  const SizedBox(width: 15),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                    iconSize: 12,
                    padding: EdgeInsets.zero,
                    splashRadius: 0.0001,
                    tooltip: 'Rename file...',
                    onPressed: () => ref.read(settingsProvider.notifier).setFontSize(int.parse(fontSizeController.text)),
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
                        onSubmitted: (tags) {},
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                      icon: const Icon(Icons.add),
                      constraints: const BoxConstraints(minHeight: 12, maxHeight: 12),
                      iconSize: 12,
                      padding: EdgeInsets.zero,
                      splashRadius: 0.0001,
                      tooltip: 'Rename file...',
                      onPressed: () => ref.read(settingsProvider.notifier).setFontSize(int.parse(fontSizeController.text)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}