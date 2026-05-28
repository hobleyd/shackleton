import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;

import '../domain/services/i_face_recognition_service.dart';
import 'face_recognition_isolate.dart';

class FaceRecognitionService implements IFaceRecognitionService {
  static const _zipUrl =
      'https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip';
  static const _detModelName = 'det_10g.onnx';
  static const _recModelName = 'w600k_r50.onnx';
  static const _detMinBytes = 10 * 1024 * 1024;
  static const _recMinBytes = 80 * 1024 * 1024;

  String? _modelsDir;

  // ── Worker isolate state ──────────────────────────────────────────────────

  Isolate? _workerIsolate;
  SendPort? _commandPort;
  // Guards against concurrent _ensureWorker() calls.
  Completer<void>? _startingCompleter;

  Future<void> _ensureWorker() async {
    if (_commandPort != null) return;

    if (_startingCompleter != null) {
      await _startingCompleter!.future;
      return;
    }
    _startingCompleter = Completer<void>();

    try {
      final dir = await _getModelsDir();
      final initPort = ReceivePort();
      final iter = StreamIterator<Object?>(initPort);

      _workerIsolate = await Isolate.spawn(
        faceRecognitionIsolateEntry,
        [
          path.join(dir, _detModelName),
          path.join(dir, _recModelName),
          initPort.sendPort,
        ],
      );

      // Step 1: worker sends back its command SendPort.
      await iter.moveNext();
      _commandPort = iter.current as SendPort;

      // Step 2: worker sends true once models are loaded.
      await iter.moveNext();

      await iter.cancel();
      _startingCompleter!.complete();
    } catch (e) {
      _startingCompleter!.completeError(e);
      _startingCompleter = null;
      rethrow;
    }
  }

  // ── IFaceRecognitionService ───────────────────────────────────────────────

  @override
  Future<bool> get modelsAvailable async {
    final dir = await _getModelsDir();
    final detFile = File(path.join(dir, _detModelName));
    final recFile = File(path.join(dir, _recModelName));
    return detFile.existsSync() &&
        detFile.lengthSync() >= _detMinBytes &&
        recFile.existsSync() &&
        recFile.lengthSync() >= _recMinBytes;
  }

  @override
  Future<void> downloadModels({
    void Function(String message, double progress)? onProgress,
  }) async {
    final dir = await _getModelsDir();

    for (final entry in [
      (path.join(dir, _detModelName), _detMinBytes),
      (path.join(dir, _recModelName), _recMinBytes),
    ]) {
      final f = File(entry.$1);
      if (f.existsSync() && f.lengthSync() < entry.$2) await f.delete();
    }

    if (await modelsAvailable) {
      onProgress?.call('Models ready', 1.0);
      return;
    }

    final zipPath = path.join(dir, 'buffalo_l.zip.tmp');
    onProgress?.call('Connecting to model server…', 0.0);

    final httpClient = HttpClient();
    try {
      final request = await httpClient.getUrl(Uri.parse(_zipUrl));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} downloading models');
      }
      final total = response.contentLength;
      var received = 0;
      final sink = File(zipPath).openWrite();
      try {
        await for (final chunk in response) {
          sink.add(chunk);
          received += chunk.length;
          final mb = (received / 1024 / 1024).toStringAsFixed(0);
          final progress = total > 0 ? (received / total) * 0.8 : 0.0;
          onProgress?.call('Downloading models… ($mb MB)', progress);
        }
      } finally {
        await sink.close();
      }
    } finally {
      httpClient.close(force: false);
    }

    onProgress?.call('Extracting models…', 0.82);
    final inputStream = InputFileStream(zipPath);
    try {
      final archive = ZipDecoder().decodeStream(inputStream);
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = path.basename(file.name);
        if (name != _detModelName && name != _recModelName) continue;
        final outStream = OutputFileStream(path.join(dir, name));
        try {
          file.writeContent(outStream);
        } finally {
          outStream.close();
        }
      }
    } finally {
      inputStream.close();
      await File(zipPath).delete().catchError((_) => File(zipPath));
    }

    if (!await modelsAvailable) {
      throw Exception('Model extraction failed — files missing or too small. Please try again.');
    }

    onProgress?.call('Models ready', 1.0);
  }

  @override
  Future<List<FaceDetection>> detectFaces(String imagePath) async {
    if (!await modelsAvailable) {
      throw StateError('Models not downloaded. Call downloadModels() first.');
    }
    await _ensureWorker();

    final replyPort = ReceivePort();
    _commandPort!.send([imagePath, replyPort.sendPort]);
    final result = await replyPort.first;
    replyPort.close();

    if (result is String) throw Exception(result);
    return (result as List).cast<FaceDetection>();
  }

  @override
  double cosineSimilarity(Float32List a, Float32List b) {
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  @override
  void dispose() {
    _commandPort?.send(null);
    _workerIsolate?.kill(priority: Isolate.immediate);
    _commandPort = null;
    _workerIsolate = null;
    _startingCompleter = null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<String> _getModelsDir() async {
    if (_modelsDir != null) return _modelsDir!;
    final String dir;
    if (Platform.isWindows) {
      dir = path.join(Platform.environment['APPDATA']!, 'Shackleton', 'models');
    } else {
      dir = path.join(Platform.environment['HOME']!, '.shackleton', 'models');
    }
    await Directory(dir).create(recursive: true);
    return _modelsDir = dir;
  }
}
