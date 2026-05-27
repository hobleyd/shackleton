import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/file_of_interest.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/face_recognition_provider.dart';

class FaceSearchPanel extends ConsumerStatefulWidget {
  const FaceSearchPanel({super.key});

  @override
  ConsumerState<FaceSearchPanel> createState() => _FaceSearchPanelState();
}

class _FaceSearchPanelState extends ConsumerState<FaceSearchPanel> {
  final _nameController = TextEditingController();
  double _threshold = 0.35;

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

    final referenceFile = selected.isNotEmpty ? selected.first : null;
    final isWorking = faceState.status == FaceSearchStatus.scanning ||
        faceState.status == FaceSearchStatus.downloadingModels;

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

          // Scan button
          FilledButton(
            onPressed: isWorking ||
                    referenceFile == null ||
                    !referenceFile.isImage ||
                    _nameController.text.trim().isEmpty
                ? null
                : () => _startSearch(referenceFile, gridFiles),
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

  void _startSearch(FileOfInterest referenceFile, List<FileOfInterest> libraryFiles) {
    ref.read(faceSearchProvider.notifier).search(
          referenceFile: referenceFile,
          personName: _nameController.text,
          threshold: _threshold,
          libraryFiles: libraryFiles,
        );
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
