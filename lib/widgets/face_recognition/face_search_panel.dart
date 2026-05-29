import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../domain/services/i_face_recognition_service.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/face_recognition_provider.dart';
import '../../repositories/app_settings_repository.dart';

// Top-level function required by compute().
Future<Uint8List?> _cropFaceBytes(List<dynamic> args) async {
  final path = args[0] as String;
  final bx = (args[1] as double).toInt();
  final by = (args[2] as double).toInt();
  final bw = (args[3] as double).toInt();
  final bh = (args[4] as double).toInt();

  final bytes = await File(path).readAsBytes();
  final src = img.decodeImage(bytes);
  if (src == null) return null;

  // 30% padding so the crop feels like a portrait rather than a tight box.
  final pad = (bw * 0.30).round();
  final x = (bx - pad).clamp(0, src.width - 1);
  final y = (by - pad).clamp(0, src.height - 1);
  final w = (bw + 2 * pad).clamp(1, src.width - x);
  final h = (bh + 2 * pad).clamp(1, src.height - y);

  final cropped = img.copyCrop(src, x: x, y: y, width: w, height: h);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 80));
}

class FaceSearchPanel extends ConsumerStatefulWidget {
  const FaceSearchPanel({super.key});

  @override
  ConsumerState<FaceSearchPanel> createState() => _FaceSearchPanelState();
}

class _FaceSearchPanelState extends ConsumerState<FaceSearchPanel> {
  final List<TextEditingController> _nameControllers = [];
  List<bool> _faceVisible = [];
  double _threshold = 0.35;
  String? _selectedScopePath;

  int _controllerCount = 0;

  @override
  void dispose() {
    for (final c in _nameControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncControllers(int faceCount) {
    if (faceCount == _controllerCount) return;
    for (final c in _nameControllers) {
      c.dispose();
    }
    _nameControllers.clear();
    _faceVisible = List.filled(faceCount, true);
    for (var i = 0; i < faceCount; i++) {
      final c = TextEditingController();
      c.addListener(() => setState(() {}));
      _nameControllers.add(c);
    }
    _controllerCount = faceCount;
  }

  @override
  Widget build(BuildContext context) {
    final faceState = ref.watch(faceSearchProvider);
    final selected = ref.watch(selectedGridEntitiesProvider);
    final gridFiles = ref.watch(gridContentsProvider);
    final selectedFolders = ref.watch(selectedFolderContentsProvider);
    final libraryPath = ref.watch(appSettingsRepositoryProvider).asData?.value.libraryPath;

    final referenceFile = selected.isNotEmpty ? selected.first : null;
    final isWorking = faceState.status == FaceSearchStatus.scanning ||
        faceState.status == FaceSearchStatus.downloadingModels ||
        faceState.status == FaceSearchStatus.detecting ||
        faceState.status == FaceSearchStatus.tagging;

    // Sync name controllers to the current detected face count.
    final detectedFaces = faceState.referenceFaces;
    final faceCount = detectedFaces?.length ?? 0;
    _syncControllers(faceCount);

    final scopeOptions = libraryPath != null
        ? _buildScopeOptions(_currentFolderPath(selectedFolders, gridFiles, libraryPath), libraryPath)
        : <({String label, String path})>[];

    if (_selectedScopePath != null &&
        scopeOptions.isNotEmpty &&
        !scopeOptions.any((o) => o.path == _selectedScopePath)) {
      _selectedScopePath = null;
    }

    final activeScopePath = scopeOptions.isNotEmpty
        ? (_selectedScopePath ?? scopeOptions.first.path)
        : libraryPath;

    // The reference photo shown in state may differ from the currently selected
    // file. Faces are only valid for the file they were detected from.
    final facesAreForCurrentFile =
        detectedFaces != null && faceState.referencePath == referenceFile?.path;

    final canDetect = !isWorking && referenceFile != null && referenceFile.isImage;

    final namedFaces = facesAreForCurrentFile
        ? [
            for (var i = 0; i < detectedFaces.length; i++)
              if (_faceVisible[i] && _nameControllers[i].text.trim().isNotEmpty)
                (face: detectedFaces[i], name: _nameControllers[i].text.trim()),
          ]
        : <({FaceDetection face, String name})>[];

    final canSearch = !isWorking &&
        facesAreForCurrentFile &&
        namedFaces.isNotEmpty &&
        activeScopePath != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Face Search',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              if (faceState.status != FaceSearchStatus.idle)
                IconButton(
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: const Icon(Icons.close),
                  onPressed: () => ref.read(faceSearchProvider.notifier).reset(),
                  tooltip: 'Reset',
                ),
            ],
          ),
          const SizedBox(height: 10),

          // Reference photo indicator
          _ReferencePhotoTile(file: referenceFile),
          const SizedBox(height: 8),

          // Detect button — always shown; changes label when re-detecting.
          OutlinedButton.icon(
            onPressed: canDetect
                ? () => ref.read(faceSearchProvider.notifier).detectReferenceFaces(referenceFile)
                : null,
            icon: const Icon(Icons.face_retouching_natural, size: 14),
            label: Text(
              detectedFaces != null ? 'Re-detect Faces' : 'Detect Faces',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // Progress / status for detect and scan phases
          if (isWorking) ...[
            LinearProgressIndicator(value: faceState.progress > 0 ? faceState.progress : null),
            const SizedBox(height: 4),
            Text(
              faceState.message,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
          ] else if (faceState.status == FaceSearchStatus.error) ...[
            Text(
              faceState.errorMessage ?? 'Unknown error',
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
            const SizedBox(height: 4),
          ] else if (faceState.status == FaceSearchStatus.done && faceState.results.isEmpty) ...[
            Text(
              faceState.message,
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(height: 4),
          ] else if (faceState.status == FaceSearchStatus.idle && faceState.message.isNotEmpty) ...[
            Text(
              faceState.message,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
            const SizedBox(height: 4),
          ],

          // Detected face cards — scrollable so large group photos don't overflow.
          if (facesAreForCurrentFile) ...[
            const Divider(),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: detectedFaces.length,
                separatorBuilder: (context, i) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  if (!_faceVisible[i]) return const SizedBox.shrink();
                  return _FaceCard(
                    index: i,
                    imagePath: faceState.referencePath!,
                    face: detectedFaces[i],
                    nameController: _nameControllers[i],
                    enabled: !isWorking,
                    onDismiss: () => setState(() => _faceVisible[i] = false),
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Similarity threshold
          Row(
            children: [
              const Text('Match threshold', style: TextStyle(fontSize: 10)),
              const Spacer(),
              Text(
                _threshold.toStringAsFixed(2),
                style: const TextStyle(fontSize: 10),
              ),
            ],
          ),
          Slider(
            value: _threshold,
            min: 0.1,
            max: 0.8,
            divisions: 70,
            onChanged: isWorking ? null : (v) => setState(() => _threshold = v),
          ),

          // Search scope dropdown
          if (scopeOptions.isNotEmpty) ...[
            DropdownButtonFormField<String>(
              initialValue: _selectedScopePath ?? scopeOptions.first.path,
              isDense: true,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Search scope',
                labelStyle: TextStyle(fontSize: 11),
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
              style: const TextStyle(fontSize: 11, color: Colors.black),
              items: scopeOptions
                  .map((o) => DropdownMenuItem(
                        value: o.path,
                        child: Text(
                          o.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: Colors.black),
                        ),
                      ))
                  .toList(),
              onChanged: isWorking ? null : (v) => setState(() => _selectedScopePath = v),
            ),
            const SizedBox(height: 8),
          ],

          // Search button
          FilledButton(
            onPressed: canSearch
                ? () => _startSearch(namedFaces, gridFiles, activeScopePath)
                : null,
            child: Text(
              namedFaces.length > 1
                  ? 'Find ${namedFaces.length} People'
                  : 'Find Matching Faces',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),

          // Results
          if (faceState.results.isNotEmpty) ...[
            const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Untagged matches',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: isWorking
                      ? null
                      : () => ref.read(faceSearchProvider.notifier).tagAll(),
                  child: const Text('Tag all', style: TextStyle(fontSize: 10)),
                ),
              ],
            ),
            if (faceState.status == FaceSearchStatus.done) ...[
              Text(
                faceState.message,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              const SizedBox(height: 4),
            ],
            Expanded(
              child: ListView.builder(
                itemCount: faceState.results.length,
                itemBuilder: (context, i) {
                  final match = faceState.results[i];
                  return _MatchTile(match: match);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _currentFolderPath(
      Set<FileOfInterest> selectedFolders, List<FileOfInterest> gridFiles, String libraryPath) {
    final dirs = selectedFolders.where((f) => f.isDirectory).toList();
    if (dirs.isNotEmpty) return dirs.first.path;
    if (gridFiles.isNotEmpty) return p.dirname(gridFiles.first.path);
    return libraryPath;
  }

  List<({String label, String path})> _buildScopeOptions(String currentPath, String libraryPath) {
    if (!currentPath.startsWith(libraryPath)) {
      return [(label: p.basename(libraryPath), path: libraryPath)];
    }
    final options = <({String label, String path})>[];
    String cursor = currentPath;
    while (true) {
      options.add((label: p.basename(cursor), path: cursor));
      if (cursor == libraryPath) break;
      final parent = p.dirname(cursor);
      if (parent == cursor) break;
      cursor = parent;
    }
    return options;
  }

  void _startSearch(
    List<({FaceDetection face, String name})> namedFaces,
    List<FileOfInterest> gridFiles,
    String scopePath,
  ) {
    final files = (scopePath ==
            _currentFolderPath(
              ref.read(selectedFolderContentsProvider),
              gridFiles,
              ref.read(appSettingsRepositoryProvider).asData?.value.libraryPath ?? scopePath,
            ))
        ? gridFiles
        : _collectImages(scopePath);

    ref.read(faceSearchProvider.notifier).search(
          namedFaces: namedFaces,
          threshold: _threshold,
          libraryFiles: files,
        );
  }

  List<FileOfInterest> _collectImages(String folderPath) {
    final dir = Directory(folderPath);
    if (!dir.existsSync()) return [];
    return dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((f) => FileOfInterest(entity: f))
        .where((f) => f.isImage)
        .toList();
  }
}

class _ReferencePhotoTile extends StatelessWidget {
  final FileOfInterest? file;

  const _ReferencePhotoTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final label = file != null && file!.isImage
        ? file!.path.split('/').last
        : 'Select an image in the grid';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: file != null && file!.isImage
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            file != null && file!.isImage ? Icons.photo : Icons.image_not_supported,
            size: 14,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _FaceCard extends StatefulWidget {
  final int index;
  final String imagePath;
  final FaceDetection face;
  final TextEditingController nameController;
  final bool enabled;
  final VoidCallback onDismiss;

  const _FaceCard({
    required this.index,
    required this.imagePath,
    required this.face,
    required this.nameController,
    required this.enabled,
    required this.onDismiss,
  });

  @override
  State<_FaceCard> createState() => _FaceCardState();
}

class _FaceCardState extends State<_FaceCard> {
  late Future<Uint8List?> _thumbFuture;

  @override
  void initState() {
    super.initState();
    _thumbFuture = compute(_cropFaceBytes, [
      widget.imagePath,
      widget.face.bboxX,
      widget.face.bboxY,
      widget.face.bboxW,
      widget.face.bboxH,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Face thumbnail
        SizedBox(
          width: 56,
          height: 56,
          child: FutureBuilder<Uint8List?>(
            future: _thumbFuture,
            builder: (ctx, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              if (snap.data == null) {
                return Container(
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(Icons.face, size: 28, color: Colors.grey[500]),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.memory(snap.data!, fit: BoxFit.cover),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        // Name field
        Expanded(
          child: TextField(
            controller: widget.nameController,
            enabled: widget.enabled,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Person ${widget.index + 1}',
              labelStyle: const TextStyle(fontSize: 11),
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
        ),
        // Dismiss button
        IconButton(
          iconSize: 14,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
          icon: const Icon(Icons.close),
          tooltip: 'Remove from search',
          onPressed: widget.enabled ? widget.onDismiss : null,
        ),
      ],
    );
  }
}

class _MatchTile extends StatelessWidget {
  final ({FileOfInterest file, double similarity, String personName}) match;

  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              match.file.path.split('/').last,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            match.personName,
            style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.primary),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(width: 4),
          Text(
            '${(match.similarity * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
