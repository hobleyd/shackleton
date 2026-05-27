import 'dart:io';

import 'package:desktop_updater/desktop_updater.dart';
import 'package:desktop_updater/updater_controller.dart';
import 'package:flutter/material.dart';

class ShackletonUpdate extends StatefulWidget {
  const ShackletonUpdate({super.key});

  @override
  State<ShackletonUpdate> createState() => _ShackletonUpdateState();
}

class _ShackletonUpdateState extends State<ShackletonUpdate> {
  DesktopUpdaterController? _controller;

  static const String _appArchiveUrl = 'https://hobleyd.github.io/shackleton/app-archive.json';

  @override
  void initState() {
    super.initState();
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      _controller = DesktopUpdaterController(
        appArchiveUrl: Uri.parse(_appArchiveUrl),
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _controller!,
      builder: (context, _) {
        if (_controller!.needUpdate) {
          return DesktopUpdateDirectCard(
            controller: _controller!,
            child: const SizedBox.shrink(),
          );
        }
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Shackleton is up to date.',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Check for updates',
                onPressed: _controller!.checkVersion,
              ),
            ),
          ],
        );
      },
    );
  }
}
