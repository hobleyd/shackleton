import 'dart:io';

import 'package:desktop_updater/desktop_updater.dart';
import 'package:desktop_updater/updater_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Subclass so UpdateCard's `notifier?.restartApp()` dispatches to our
// override, where we can surface errors that the base class drops.
class _ShackletonUpdaterController extends DesktopUpdaterController {
  _ShackletonUpdaterController({required super.appArchiveUrl});

  String? restartError;

  static const _channel = MethodChannel('desktop_updater');

  @override
  void restartApp() {
    restartError = null;
    _channel.invokeMethod<void>('restartApp').catchError((dynamic e) {
      restartError = e is PlatformException
          ? (e.message ?? 'Restart failed')
          : 'Restart failed: $e';
      notifyListeners();
    });
  }
}

class ShackletonUpdate extends StatefulWidget {
  const ShackletonUpdate({super.key});

  @override
  State<ShackletonUpdate> createState() => _ShackletonUpdateState();
}

class _ShackletonUpdateState extends State<ShackletonUpdate> {
  _ShackletonUpdaterController? _controller;
  String _version = '';

  static const String _appArchiveUrl = 'https://hobleyd.github.io/shackleton/app-archive.json';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      _controller = _ShackletonUpdaterController(
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
        final error = _controller!.restartError;
        if (error != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Restart failed: $error')),
              );
              _controller!.restartError = null;
            }
          });
        }
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
                'Shackleton${_version.isNotEmpty ? ' [$_version]' : ''} is up to date.',
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
