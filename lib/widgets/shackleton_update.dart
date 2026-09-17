import 'dart:async';
import 'dart:io';

import 'package:desktop_updater/desktop_updater.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../services/update_recovery_store.dart';

/// Must match `--package-id` in the release workflow's packaging steps and
/// the `packageId` bound into each signed release descriptor.
const String _updatePackageId = 'au.com.sharpblue.shackleton';

/// Pinned Ed25519 public keys from `desktop_updater.keys.json`.
///
/// Only an app-archive and release descriptor signed by the matching private
/// key -- a GitHub Actions secret, never in this repository -- are trusted.
/// TODO: replace with the exact "Public key map" printed by
/// `dart run desktop_updater:release keygen` (see tool/setup_updater.sh)
/// before the first signed release is published.
const Map<String, String> _trustedReleasePublicKeys = {};

class ShackletonUpdate extends StatefulWidget {
  const ShackletonUpdate({super.key});

  @override
  State<ShackletonUpdate> createState() => _ShackletonUpdateState();
}

class _ShackletonUpdateState extends State<ShackletonUpdate> {
  DesktopUpdaterController? _controller;
  String _version = '';

  static const String _appArchiveUrl = 'https://hobleyd.github.io/shackleton/app-archive.json';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      unawaited(_initController());
    }
  }

  Future<void> _initController() async {
    final supportDirectory = await getApplicationSupportDirectory();
    final recoveryFile = File(
      '${supportDirectory.path}${Platform.pathSeparator}'
      'desktop_updater${Platform.pathSeparator}pending-install.json',
    );
    final controller = DesktopUpdaterController(
      appArchiveUrl: Uri.parse(_appArchiveUrl),
      expectedPackageId: _updatePackageId,
      trustedReleasePublicKeys: _trustedReleasePublicKeys,
      recoveryStore: ShackletonUpdateRecoveryStore(recoveryFile),
    );
    if (mounted) setState(() => _controller = controller);
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
        final state = _controller!.state;
        if (state is UpdateFailed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Update failed: ${state.error}')),
              );
            }
          });
        }
        final needUpdate = state is UpdateAvailable ||
            state is UpdateDownloading ||
            state is UpdateReadyToInstall ||
            state is UpdateInstalling;
        if (needUpdate) {
          return DesktopUpdateDirectCard(
            controller: _controller!,
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
