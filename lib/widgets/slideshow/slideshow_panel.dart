import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:url_launcher/url_launcher.dart';

import '../../domain/services/i_slideshow_exporter.dart';
import '../../misc/utils.dart';
import '../../models/file_of_interest.dart';
import '../../providers/contents/grid_contents.dart';
import '../../providers/contents/selected_grid_entities.dart';
import '../../providers/slideshow_exporter_provider.dart';

// ── Built-in classical music catalogue ───────────────────────────────────────

class _ClassicalTrack {
  final String title;
  final String composer;

  /// Asset path under assets/music/ (without the assets/music/ prefix).
  final String assetFile;

  const _ClassicalTrack(this.title, this.composer, this.assetFile);

  String get assetPath => 'assets/music/$assetFile';
}

const _classicalCatalogue = [
  _ClassicalTrack('Canon in D',              'Pachelbel',  'canon_in_d.wav'),
  _ClassicalTrack('Air on the G String',     'Bach',       'air_on_the_g_string.wav'),
  _ClassicalTrack('Moonlight Sonata',        'Beethoven',  'moonlight_sonata.wav'),
  _ClassicalTrack('Clair de Lune',           'Debussy',    'clair_de_lune.wav'),
  _ClassicalTrack('Nocturne Op.9 No.2',      'Chopin',     'nocturne.wav'),
  _ClassicalTrack('Ride of the Valkyries',   'Wagner',     'ride_of_the_valkyries.wav'),
];

/// Extracts a bundled asset to a temp WAV file and returns the file path.
/// The caller is responsible for deleting the file when done.
Future<String> _extractAssetToTemp(_ClassicalTrack track) async {
  final data    = await rootBundle.load(track.assetPath);
  final tmpFile = File(p.join(
    Directory.systemTemp.path,
    'shackleton_music_${track.assetFile}',
  ));
  await tmpFile.writeAsBytes(data.buffer.asUint8List());
  return tmpFile.path;
}

// ── Panel widget ──────────────────────────────────────────────────────────────

enum _PanelState { idle, creating, done, error }

class SlideshowPanel extends ConsumerStatefulWidget {
  const SlideshowPanel({super.key});

  @override
  ConsumerState<SlideshowPanel> createState() => _SlideshowPanelState();
}

class _SlideshowPanelState extends ConsumerState<SlideshowPanel> {
  _PanelState _state          = _PanelState.idle;
  int _imageCount             = 0; // 0 = all available
  int _frameDelaySec          = 3;
  final Set<SlideshowTransition> _transitions = {SlideshowTransition.fade};
  SlideshowQuality _quality   = SlideshowQuality.medium;
  int _progressCurrent        = 0;
  int _progressTotal          = 0;
  _ClassicalTrack? _selectedTrack;   // non-null when a built-in track is chosen
  String? _selectedCustomAudioPath;  // non-null when user browsed a file
  String? _outputPath;
  String? _errorMessage;

  // Preview playback
  late final Player _previewPlayer;
  bool _isPlaying = false;
  String? _previewTempPath; // temp file for the currently loaded built-in track

  @override
  void initState() {
    super.initState();
    _previewPlayer = Player();
    _previewPlayer.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    _deletePreviewTemp();
    super.dispose();
  }

  void _deletePreviewTemp() {
    if (_previewTempPath != null) {
      try { File(_previewTempPath!).deleteSync(); } catch (_) {}
      _previewTempPath = null;
    }
  }

  Future<void> _selectTrack(_ClassicalTrack? track) async {
    await _previewPlayer.stop();
    _deletePreviewTemp();
    setState(() {
      _selectedTrack = track;
      _selectedCustomAudioPath = null;
    });
  }

  Future<void> _togglePreview() async {
    if (_isPlaying) {
      await _previewPlayer.stop();
      return;
    }
    String? audioPath;
    if (_selectedTrack != null) {
      _previewTempPath ??= await _extractAssetToTemp(_selectedTrack!);
      audioPath = _previewTempPath;
    } else {
      audioPath = _selectedCustomAudioPath;
    }
    if (audioPath == null) return;
    await _previewPlayer.open(Media('file://$audioPath'));
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedGridEntitiesProvider);
    final grid     = ref.watch(gridContentsProvider);

    final sourceImages = selected.any((f) => f.isImage)
        ? selected.where((f) => f.isImage).toList()
        : grid.where((f) => f.isImage).toList();

    final maxCount      = sourceImages.length;
    final effectiveCount = (_imageCount == 0 ? maxCount : _imageCount).clamp(1, maxCount);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Create Slideshow', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),

          if (_state == _PanelState.creating)
            _buildCreating()
          else if (_state == _PanelState.done && _outputPath != null)
            _buildDone(context)
          else
            _buildConfig(context, sourceImages, maxCount, effectiveCount),

          if (_state == _PanelState.error && _errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(_errorMessage!,
                style: const TextStyle(fontSize: 10, color: Colors.red)),
          ],
        ],
      ),
    );
  }

  // ── creating ──────────────────────────────────────────────────────────────

  Widget _buildCreating() => Column(children: [
        LinearProgressIndicator(
          value: _progressTotal > 0 ? _progressCurrent / _progressTotal : null,
        ),
        const SizedBox(height: 8),
        Text(
          _progressTotal > 0
              ? 'Image $_progressCurrent of $_progressTotal…'
              : 'Building slideshow…',
          style: const TextStyle(fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ]);

  // ── done ──────────────────────────────────────────────────────────────────

  Widget _buildDone(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(p.basename(_outputPath!),
                    style: const TextStyle(fontSize: 10),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: _openFile,
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Open Slideshow', style: TextStyle(fontSize: 12)),
          ),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: _showInFinder,
            icon: const Icon(Icons.folder_open, size: 14),
            label: Text(
              Platform.isMacOS ? 'Show in Finder' : 'Show in Explorer',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() {
              _state      = _PanelState.idle;
              _outputPath = null;
            }),
            child: const Text('Create another', style: TextStyle(fontSize: 11)),
          ),
        ],
      );

  // ── config ────────────────────────────────────────────────────────────────

  Widget _buildConfig(
    BuildContext context,
    List<FileOfInterest> sourceImages,
    int maxCount,
    int effectiveCount,
  ) {
    if (maxCount == 0) {
      return Center(
          child: Text('No images in grid',
              style: Theme.of(context).textTheme.bodySmall));
    }

    final usingSelected =
        ref.read(selectedGridEntitiesProvider).any((f) => f.isImage);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Source summary
        _chip(
          context,
          '$effectiveCount of $maxCount image${maxCount == 1 ? '' : 's'}'
          '${usingSelected ? ' (selected)' : ''}',
        ),
        const SizedBox(height: 10),

        // ── Image count ──
        Row(children: [
          const Text('Images', style: TextStyle(fontSize: 10)),
          const Spacer(),
          Text('$effectiveCount', style: const TextStyle(fontSize: 10)),
        ]),
        Slider(
          value: effectiveCount.toDouble(),
          min: 1,
          max: maxCount.toDouble(),
          divisions: maxCount > 1 ? maxCount - 1 : 1,
          onChanged: maxCount > 1
              ? (v) => setState(() => _imageCount = v.round())
              : null,
        ),
        const SizedBox(height: 2),

        // ── Duration ──
        Row(children: [
          const Text('Duration / image', style: TextStyle(fontSize: 10)),
          const Spacer(),
          Text('${_frameDelaySec}s', style: const TextStyle(fontSize: 10)),
        ]),
        Slider(
          value: _frameDelaySec.toDouble(),
          min: 1, max: 10, divisions: 9,
          onChanged: (v) => setState(() => _frameDelaySec = v.round()),
        ),
        const SizedBox(height: 2),

        // ── Transitions ──
        const Text('Transitions', style: TextStyle(fontSize: 10)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 4, runSpacing: 2,
          children: [
            for (final t in SlideshowTransition.values)
              FilterChip(
                label: Text(_transitionLabel(t),
                    style: const TextStyle(fontSize: 9)),
                selected: _transitions.contains(t),
                visualDensity: VisualDensity.compact,
                onSelected: (on) => setState(() {
                  if (on) {
                    _transitions.add(t);
                  } else {
                    _transitions.remove(t);
                  }
                }),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Quality ──
        Row(children: [
          const Text('Quality', style: TextStyle(fontSize: 10)),
          const Spacer(),
          DropdownButton<SlideshowQuality>(
            value: _quality,
            isDense: true,
            onChanged: (q) => setState(() => _quality = q!),
            items: [
              for (final q in SlideshowQuality.values)
                DropdownMenuItem(
                  value: q,
                  child: Text(q.label, style: const TextStyle(fontSize: 10)),
                ),
            ],
          ),
        ]),
        const SizedBox(height: 4),
        const Divider(),

        // ── Music ──
        _buildMusicSection(context),
        const SizedBox(height: 12),

        FilledButton(
          onPressed: () =>
              _createSlideshow(sourceImages.take(effectiveCount).toList()),
          child: const Text('Create Slideshow',
              style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  // ── Music section ─────────────────────────────────────────────────────────

  Widget _buildMusicSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(children: [
          Icon(Icons.music_note, size: 12),
          SizedBox(width: 4),
          Text('Music', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),

        // Built-in track dropdown + play button
        Row(children: [
          Expanded(
            child: DropdownButton<_ClassicalTrack?>(
              value: _selectedTrack,
              isExpanded: true,
              isDense: true,
              onChanged: (track) => _selectTrack(track),
              items: [
                const DropdownMenuItem<_ClassicalTrack?>(
                  value: null,
                  child: Text('No music', style: TextStyle(fontSize: 10)),
                ),
                for (final track in _classicalCatalogue)
                  DropdownMenuItem<_ClassicalTrack?>(
                    value: track,
                    child: Text('${track.title} – ${track.composer}',
                        style: const TextStyle(fontSize: 10)),
                  ),
              ],
            ),
          ),
          if (_selectedTrack != null) ...[
            const SizedBox(width: 4),
            _previewButton(),
          ],
        ]),

        // Custom audio file chip
        if (_selectedCustomAudioPath != null) ...[
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: _chip(context, p.basename(_selectedCustomAudioPath!),
                  icon: Icons.audio_file),
            ),
            const SizedBox(width: 4),
            _previewButton(),
            const SizedBox(width: 2),
            GestureDetector(
              onTap: () async {
                await _previewPlayer.stop();
                setState(() => _selectedCustomAudioPath = null);
              },
              child: const Icon(Icons.close, size: 12),
            ),
          ]),
        ],

        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: _browseMusicFile,
          icon: const Icon(Icons.folder_open, size: 12),
          label: const Text('Browse for audio file…', style: TextStyle(fontSize: 11)),
        ),
      ],
    );
  }

  Widget _previewButton() => SizedBox(
        width: 28,
        height: 28,
        child: IconButton(
          padding: EdgeInsets.zero,
          iconSize: 16,
          tooltip: _isPlaying ? 'Stop' : 'Preview',
          icon: Icon(_isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: _togglePreview,
        ),
      );

  static String _transitionLabel(SlideshowTransition t) => switch (t) {
    SlideshowTransition.fade   => 'Fade',
    SlideshowTransition.flip   => 'Flip',
    SlideshowTransition.spiral => 'Spiral',
  };

  Widget _chip(BuildContext context, String label, {IconData? icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(children: [
        if (icon != null) ...[Icon(icon, size: 12), const SizedBox(width: 4)],
        Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 10),
                overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  // ── Music file browser ────────────────────────────────────────────────────

  Future<void> _browseMusicFile() async {
    final path = await _platformPickAudio();
    if (path != null && mounted) {
      await _previewPlayer.stop();
      _deletePreviewTemp();
      setState(() {
        _selectedCustomAudioPath = path;
        _selectedTrack = null;
      });
    }
  }

  Future<String?> _platformPickAudio() async {
    try {
      if (Platform.isMacOS) {
        const script = '''
tell application "System Events"
  try
    set f to choose file of type ¬
      {"mp3", "m4a", "aac", "wav", "flac", "aiff", "ogg"} ¬
      with prompt "Select an audio file for the slideshow"
    return POSIX path of f
  on error
    return ""
  end try
end tell''';
        final res = await Process.run('osascript', ['-e', script]);
        final path = (res.stdout as String).trim();
        return path.isEmpty ? null : path;

      } else if (Platform.isWindows) {
        final res = await Process.run('powershell', ['-command',
          r'''
Add-Type -AssemblyName System.Windows.Forms
$f = New-Object System.Windows.Forms.OpenFileDialog
$f.Filter = 'Audio Files|*.mp3;*.m4a;*.aac;*.wav;*.flac;*.ogg;*.wma'
$f.ShowDialog() | Out-Null
Write-Output $f.FileName
'''
        ]);
        final path = (res.stdout as String).trim();
        return path.isEmpty ? null : path;

      } else {
        // Linux: try zenity then kdialog.
        for (final cmd in [
          ['zenity', '--file-selection',
           '--file-filter=Audio|*.mp3 *.flac *.wav *.ogg *.m4a *.aac',
           '--title=Select audio file'],
          ['kdialog', '--getopenfilename', getHomeFolder(),
           '*.mp3 *.flac *.wav *.ogg *.m4a *.aac|Audio files'],
        ]) {
          final res = await Process.run(cmd[0], cmd.sublist(1));
          if (res.exitCode == 0) {
            final path = (res.stdout as String).trim();
            if (path.isNotEmpty) return path;
          }
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // ── Export ────────────────────────────────────────────────────────────────

  Future<void> _createSlideshow(List<FileOfInterest> images) async {
    if (images.isEmpty) return;

    final output      = _buildOutputPath('mp4');
    final transitions = Set<SlideshowTransition>.from(_transitions);

    setState(() {
      _state           = _PanelState.creating;
      _errorMessage    = null;
      _progressCurrent = 0;
      _progressTotal   = 0;
    });

    String? tmpAudioPath;
    try {
      String? resolvedAudio;
      if (_selectedTrack != null) {
        tmpAudioPath  = await _extractAssetToTemp(_selectedTrack!);
        resolvedAudio = tmpAudioPath;
      } else if (_selectedCustomAudioPath != null) {
        resolvedAudio = _selectedCustomAudioPath;
      }

      final exporter = ref.read(slideshowExporterProvider);
      if (!exporter.isAvailable) {
        throw SlideshowExportException(exporter.unavailableReason);
      }
      await exporter.export(
        imagePaths:        images.map<String>((f) => f.path).toList(),
        audioPath:         resolvedAudio,
        outputPath:        output,
        frameDelaySeconds: _frameDelaySec,
        transitions:       transitions,
        quality:           _quality,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _progressCurrent = current;
              _progressTotal   = total;
            });
          }
        },
      );

      if (mounted) setState(() { _state = _PanelState.done; _outputPath = output; });
    } on SlideshowExportException catch (e) {
      if (mounted) setState(() { _state = _PanelState.error; _errorMessage = e.message; });
    } catch (e) {
      if (mounted) setState(() { _state = _PanelState.error; _errorMessage = e.toString(); });
    } finally {
      if (tmpAudioPath != null) {
        try { File(tmpAudioPath).deleteSync(); } catch (_) {}
      }
    }
  }

  String _buildOutputPath(String ext) {
    final dir = p.join(getHomeFolder(), 'Downloads');
    Directory(dir).createSync(recursive: true);
    final ts    = DateTime.now();
    final stamp = '${ts.year}${_pad(ts.month)}${_pad(ts.day)}'
        '_${_pad(ts.hour)}${_pad(ts.minute)}${_pad(ts.second)}';
    return p.join(dir, 'slideshow_$stamp.$ext');
  }

  String _pad(int n) => n.toString().padLeft(2, '0');

  // ── File actions ──────────────────────────────────────────────────────────

  Future<void> _openFile() async {
    if (_outputPath == null) return;
    final uri = Uri.file(_outputPath!);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _showInFinder() async {
    if (_outputPath == null) return;
    if (Platform.isMacOS) {
      await Process.run('open', ['-R', _outputPath!]);
    } else if (Platform.isWindows) {
      await Process.run('explorer.exe', ['/select,', _outputPath!]);
    } else {
      final uri = Uri.directory(p.dirname(_outputPath!));
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }
}
