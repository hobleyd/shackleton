import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../models/file_of_interest.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_folder_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/face_recognition_provider.dart';
import '../../repositories/app_settings_repository.dart';

class FaceSearchPanel extends ConsumerStatefulWidget {
  const FaceSearchPanel({super.key});

  @override
  ConsumerState<FaceSearchPanel> createState() => _FaceSearchPanelState();
}

class _FaceSearchPanelState extends ConsumerState<FaceSearchPanel> {
  final _nameController = TextEditingController();
  double _threshold = 0.35;
  // null means "use the first (most specific) option"
  String? _selectedScopePath;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
        faceState.status == FaceSearchStatus.tagging;

    final scopeOptions = libraryPath != null
        ? _buildScopeOptions(_currentFolderPath(selectedFolders, gridFiles, libraryPath), libraryPath)
        : <({String label, String path})>[];

    // Reset selection when the folder changes and _selectedScopePath is no longer valid.
    if (_selectedScopePath != null &&
        scopeOptions.isNotEmpty &&
        !scopeOptions.any((o) => o.path == _selectedScopePath)) {
      _selectedScopePath = null;
    }

    final activeScopePath = scopeOptions.isNotEmpty
        ? (_selectedScopePath ?? scopeOptions.first.path)
        : libraryPath;

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

          // Person name input
          TextField(
            controller: _nameController,
            enabled: !isWorking,
            style: const TextStyle(fontSize: 12),
            decoration: const InputDecoration(
              labelText: 'Person name',
              labelStyle: TextStyle(fontSize: 11),
              isDense: true,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          const SizedBox(height: 8),

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
                        child: Text(o.label,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.black)),
                      ))
                  .toList(),
              onChanged: isWorking
                  ? null
                  : (v) => setState(() => _selectedScopePath = v),
            ),
            const SizedBox(height: 8),
          ],

          // Scan button
          FilledButton(
            onPressed: isWorking ||
                    referenceFile == null ||
                    !referenceFile.isImage ||
                    _nameController.text.trim().isEmpty ||
                    activeScopePath == null
                ? null
                : () => _startSearch(referenceFile, gridFiles, activeScopePath),
            child: const Text('Find Matching Faces', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 8),

          // Progress / status
          if (isWorking) ...[
            LinearProgressIndicator(value: faceState.progress > 0 ? faceState.progress : null),
            const SizedBox(height: 4),
            Text(
              faceState.message,
              style: const TextStyle(fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (faceState.status == FaceSearchStatus.error) ...[
            Text(
              faceState.errorMessage ?? 'Unknown error',
              style: const TextStyle(fontSize: 10, color: Colors.red),
            ),
          ] else if (faceState.status == FaceSearchStatus.done) ...[
            Text(
              faceState.message,
              style: const TextStyle(fontSize: 10),
            ),
          ],

          const SizedBox(height: 4),

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
                      : () => ref
                          .read(faceSearchProvider.notifier)
                          .tagAll(_nameController.text),
                  child: Text(
                    'Tag all as "${_nameController.text}"',
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
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

  /// Returns the effective "current folder" for the scope dropdown.
  String _currentFolderPath(
      Set<FileOfInterest> selectedFolders, List<FileOfInterest> gridFiles, String libraryPath) {
    final dirs = selectedFolders.where((f) => f.isDirectory).toList();
    if (dirs.isNotEmpty) return dirs.first.path;
    if (gridFiles.isNotEmpty) return p.dirname(gridFiles.first.path);
    return libraryPath;
  }

  /// Walks from [currentPath] up to (and including) [libraryPath], producing
  /// one entry per ancestor folder with its basename as the label.
  List<({String label, String path})> _buildScopeOptions(String currentPath, String libraryPath) {
    // Ensure we stay within the library tree.
    if (!currentPath.startsWith(libraryPath)) return [(label: p.basename(libraryPath), path: libraryPath)];

    final options = <({String label, String path})>[];
    String cursor = currentPath;
    while (true) {
      options.add((label: p.basename(cursor), path: cursor));
      if (cursor == libraryPath) break;
      final parent = p.dirname(cursor);
      if (parent == cursor) break; // filesystem root guard
      cursor = parent;
    }
    return options;
  }

  void _startSearch(FileOfInterest referenceFile, List<FileOfInterest> gridFiles, String scopePath) {
    // For the innermost scope (current folder), prefer the already-loaded gridFiles
    // so we don't re-stat the disk unnecessarily.
    final files = (scopePath == _currentFolderPath(
            ref.read(selectedFolderContentsProvider),
            gridFiles,
            ref.read(appSettingsRepositoryProvider).asData?.value.libraryPath ?? scopePath))
        ? gridFiles
        : _collectImages(scopePath);

    ref.read(faceSearchProvider.notifier).search(
          referenceFile: referenceFile,
          personName: _nameController.text,
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
            file != null && file!.isImage ? Icons.face : Icons.image_not_supported,
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

class _MatchTile extends StatelessWidget {
  final ({FileOfInterest file, double similarity}) match;

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
            '${(match.similarity * 100).toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
