import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart' as path;

import '../domain/services/i_face_recognition_service.dart';

class FaceRecognitionService implements IFaceRecognitionService {
  // buffalo_l is downloaded as a single zip (same URL the Python insightface library uses).
  static const _zipUrl =
      'https://github.com/deepinsight/insightface/releases/download/v0.7/buffalo_l.zip';
  static const _detModelName = 'det_10g.onnx';
  static const _recModelName = 'w600k_r50.onnx';

  // Sanity-check lower bounds for valid model files.
  static const _detMinBytes = 10 * 1024 * 1024;  // 10 MB
  static const _recMinBytes = 80 * 1024 * 1024;  // 80 MB

  static const _detInputSize = 640;
  static const _faceSize = 112;
  static const _detThreshold = 0.5;
  static const _nmsThreshold = 0.4;
  static const _strides = [8, 16, 32];
  static const _numAnchors = 2;

  // ArcFace 112×112 reference landmarks (left-eye, right-eye, nose, left-mouth, right-mouth).
  static const _arcfaceTemplate = [
    [38.2946, 51.6963],
    [73.5318, 51.5014],
    [56.0252, 71.7366],
    [41.5493, 92.3655],
    [70.7299, 92.2041],
  ];

  OrtSession? _detSession;
  OrtSession? _recSession;
  // Kept alive as fields so the GC never frees the native OrtRunOptions while
  // the background isolate holds a raw pointer to them during inference.
  final _detRunOpts = OrtRunOptions();
  final _recRunOpts = OrtRunOptions();
  String? _modelsDir;

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

    // Remove any corrupted (too-small) files so they get replaced.
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

    // Download the buffalo_l zip using dart:io HttpClient (follows redirects).
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

    // Extract the two ONNX files from the zip.
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

  Future<void> _ensureSessions() async {
    if (_detSession != null && _recSession != null) return;
    if (!await modelsAvailable) {
      throw StateError('Models not downloaded. Call downloadModels() first.');
    }
    final dir = await _getModelsDir();
    final opts = OrtSessionOptions();
    _detSession ??= OrtSession.fromFile(File(path.join(dir, _detModelName)), opts);
    _recSession ??= OrtSession.fromFile(File(path.join(dir, _recModelName)), opts);
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  @override
  Future<List<FaceDetection>> detectFaces(String imagePath) async {
    await _ensureSessions();

    final bytes = await File(imagePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return [];

    final scaleX = image.width / _detInputSize;
    final scaleY = image.height / _detInputSize;
    final resized = img.copyResize(image, width: _detInputSize, height: _detInputSize);
    final inputData = _preprocessImage(resized, _detInputSize, _detInputSize);

    final inputTensor = OrtValueTensor.createTensorWithDataList(
      inputData,
      [1, 3, _detInputSize, _detInputSize],
    );
    final detInputName = _detSession!.inputNames[0];
    final outputs = await (_detSession!.runAsync(_detRunOpts, {detInputName: inputTensor}) ??
        Future.value(<OrtValue?>[]));
    inputTensor.release();

    final candidates = _postprocessSCRFD(outputs, scaleX, scaleY);
    for (final o in outputs) {
      o?.release();
    }

    if (candidates.isEmpty) return [];

    final kept = _nms(
      candidates.map((c) => c.bbox).toList(),
      candidates.map((c) => c.score).toList(),
      _nmsThreshold,
    );

    final detections = <FaceDetection>[];
    for (final idx in kept) {
      final c = candidates[idx];
      final aligned = _alignFace(image, c.landmarks);
      final embedding = await _computeEmbedding(aligned);
      detections.add(FaceDetection(
        bboxX: c.bbox[0],
        bboxY: c.bbox[1],
        bboxW: c.bbox[2] - c.bbox[0],
        bboxH: c.bbox[3] - c.bbox[1],
        confidence: c.score,
        landmarks: c.landmarks,
        embedding: embedding,
      ));
    }
    return detections;
  }

  @override
  double cosineSimilarity(Float32List a, Float32List b) {
    // Both embeddings are L2-normalised so cosine similarity == dot product.
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  @override
  void dispose() {
    _detSession?.release();
    _recSession?.release();
    _detSession = null;
    _recSession = null;
    _detRunOpts.release();
    _recRunOpts.release();
  }

  // ── Image preprocessing ───────────────────────────────────────────────────

  Float32List _preprocessImage(img.Image image, int w, int h) {
    final data = Float32List(3 * h * w);
    final plane = h * w;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final p = image.getPixel(x, y);
        final i = y * w + x;
        data[i] = (p.r - 127.5) / 128.0;
        data[plane + i] = (p.g - 127.5) / 128.0;
        data[2 * plane + i] = (p.b - 127.5) / 128.0;
      }
    }
    return data;
  }

  // ── SCRFD post-processing ─────────────────────────────────────────────────

  ({List<double> bbox, double score, List<List<double>> landmarks}) _makeCandidate(
    List<double> bbox,
    double score,
    List<List<double>> landmarks,
  ) =>
      (bbox: bbox, score: score, landmarks: landmarks);

  List<({List<double> bbox, double score, List<List<double>> landmarks})> _postprocessSCRFD(
    List<OrtValue?> outputs,
    double scaleX,
    double scaleY,
  ) {
    final fmc = _strides.length; // 3
    final results = <({List<double> bbox, double score, List<List<double>> landmarks})>[];

    for (var si = 0; si < _strides.length; si++) {
      final stride = _strides[si];
      final gridH = _detInputSize ~/ stride;
      final gridW = _detInputSize ~/ stride;
      final k = gridH * gridW * _numAnchors;

      if (si >= outputs.length ||
          si + fmc >= outputs.length ||
          si + fmc * 2 >= outputs.length) {
        break;
      }

      final scoresFlat = _flattenToDoubles(outputs[si]?.value);
      final bboxesFlat = _flattenToDoubles(outputs[si + fmc]?.value);
      final kpsFlat = _flattenToDoubles(outputs[si + fmc * 2]?.value);

      if (scoresFlat.length < k || bboxesFlat.length < k * 4 || kpsFlat.length < k * 10) {
        continue;
      }

      var anchorIdx = 0;
      for (var y = 0; y < gridH; y++) {
        for (var x = 0; x < gridW; x++) {
          final cx = x * stride.toDouble();
          final cy = y * stride.toDouble();
          for (var a = 0; a < _numAnchors; a++, anchorIdx++) {
            final score = scoresFlat[anchorIdx];
            if (score < _detThreshold) continue;

            final b = anchorIdx * 4;
            final x1 = (cx - bboxesFlat[b] * stride) * scaleX;
            final y1 = (cy - bboxesFlat[b + 1] * stride) * scaleY;
            final x2 = (cx + bboxesFlat[b + 2] * stride) * scaleX;
            final y2 = (cy + bboxesFlat[b + 3] * stride) * scaleY;

            final kBase = anchorIdx * 10;
            final landmarks = [
              for (var k = 0; k < 5; k++)
                [
                  (cx + kpsFlat[kBase + k * 2] * stride) * scaleX,
                  (cy + kpsFlat[kBase + k * 2 + 1] * stride) * scaleY,
                ]
            ];

            results.add(_makeCandidate([x1, y1, x2, y2], score, landmarks));
          }
        }
      }
    }
    return results;
  }

  List<double> _flattenToDoubles(Object? value) {
    final out = <double>[];
    _flattenRecursive(value, out);
    return out;
  }

  void _flattenRecursive(Object? v, List<double> out) {
    if (v is num) {
      out.add(v.toDouble());
    } else if (v is List) {
      for (final item in v) {
        _flattenRecursive(item, out);
      }
    }
  }

  // ── NMS ───────────────────────────────────────────────────────────────────

  List<int> _nms(List<List<double>> bboxes, List<double> scores, double threshold) {
    if (bboxes.isEmpty) return [];
    final order = List.generate(scores.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final suppressed = List.filled(scores.length, false);
    final kept = <int>[];
    for (final i in order) {
      if (suppressed[i]) continue;
      kept.add(i);
      for (final j in order) {
        if (i == j || suppressed[j]) continue;
        if (_iou(bboxes[i], bboxes[j]) > threshold) suppressed[j] = true;
      }
    }
    return kept;
  }

  double _iou(List<double> a, List<double> b) {
    final x1 = max(a[0], b[0]);
    final y1 = max(a[1], b[1]);
    final x2 = min(a[2], b[2]);
    final y2 = min(a[3], b[3]);
    if (x2 <= x1 || y2 <= y1) return 0.0;
    final inter = (x2 - x1) * (y2 - y1);
    return inter / ((a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter);
  }

  // ── Face alignment ────────────────────────────────────────────────────────

  img.Image _alignFace(img.Image source, List<List<double>> landmarks) {
    final dst = [for (final p in _arcfaceTemplate) [p[0], p[1]]];
    final M = _estimateSimilarityTransform(landmarks, dst);
    return _warpAffine(source, M, _faceSize, _faceSize);
  }

  List<List<double>> _estimateSimilarityTransform(
    List<List<double>> src,
    List<List<double>> dst,
  ) {
    final n = src.length;
    // Build normal equations for similarity params [a, b, tx, ty].
    // Each point pair yields two equations:
    //   [x, -y, 1, 0] · p = x'
    //   [y,  x, 0, 1] · p = y'
    final ata = List.generate(4, (_) => List.filled(4, 0.0));
    final atb = List.filled(4, 0.0);
    for (var i = 0; i < n; i++) {
      final x = src[i][0], y = src[i][1];
      final xp = dst[i][0], yp = dst[i][1];
      final r1 = [x, -y, 1.0, 0.0];
      final r2 = [y, x, 0.0, 1.0];
      for (var j = 0; j < 4; j++) {
        for (var k = 0; k < 4; k++) {
          ata[j][k] += r1[j] * r1[k] + r2[j] * r2[k];
        }
        atb[j] += r1[j] * xp + r2[j] * yp;
      }
    }
    final p = _solveLinear4x4(ata, atb);
    return [
      [p[0], -p[1], p[2]],
      [p[1], p[0], p[3]],
    ];
  }

  List<double> _solveLinear4x4(List<List<double>> A, List<double> b) {
    final n = A.length;
    final aug = List.generate(n, (i) => [...A[i], b[i]]);
    for (var col = 0; col < n; col++) {
      var pivotRow = col;
      for (var row = col + 1; row < n; row++) {
        if (aug[row][col].abs() > aug[pivotRow][col].abs()) pivotRow = row;
      }
      final tmp = aug[col];
      aug[col] = aug[pivotRow];
      aug[pivotRow] = tmp;
      for (var row = col + 1; row < n; row++) {
        if (aug[col][col].abs() < 1e-10) continue;
        final f = aug[row][col] / aug[col][col];
        for (var k = col; k <= n; k++) {
          aug[row][k] -= f * aug[col][k];
        }
      }
    }
    final x = List.filled(n, 0.0);
    for (var i = n - 1; i >= 0; i--) {
      x[i] = aug[i][n];
      for (var j = i + 1; j < n; j++) {
        x[i] -= aug[i][j] * x[j];
      }
      if (aug[i][i].abs() > 1e-10) x[i] /= aug[i][i];
    }
    return x;
  }

  img.Image _warpAffine(img.Image src, List<List<double>> M, int outW, int outH) {
    // Inverse of the 2×3 similarity matrix for backward mapping.
    final det = M[0][0] * M[1][1] - M[0][1] * M[1][0];
    final invA = M[1][1] / det;
    final invB = -M[0][1] / det;
    final invC = -M[1][0] / det;
    final invD = M[0][0] / det;
    final tx = M[0][2], ty = M[1][2];
    final invTx = -(invA * tx + invB * ty);
    final invTy = -(invC * tx + invD * ty);

    final result = img.Image(width: outW, height: outH, numChannels: src.numChannels);
    for (var y = 0; y < outH; y++) {
      for (var x = 0; x < outW; x++) {
        final sx = (invA * x + invB * y + invTx).round();
        final sy = (invC * x + invD * y + invTy).round();
        if (sx >= 0 && sx < src.width && sy >= 0 && sy < src.height) {
          result.setPixel(x, y, src.getPixel(sx, sy));
        }
      }
    }
    return result;
  }

  // ── ArcFace embedding ─────────────────────────────────────────────────────

  Future<Float32List> _computeEmbedding(img.Image faceImage) async {
    final data = _preprocessImage(faceImage, _faceSize, _faceSize);
    final inputTensor = OrtValueTensor.createTensorWithDataList(
      data,
      [1, 3, _faceSize, _faceSize],
    );
    final recInputName = _recSession!.inputNames[0];
    final outputs = await (_recSession!.runAsync(_recRunOpts, {recInputName: inputTensor}) ??
        Future.value(<OrtValue?>[]));
    inputTensor.release();

    final flat = _flattenToDoubles(outputs.isNotEmpty ? outputs[0]?.value : null);
    for (final o in outputs) {
      o?.release();
    }

    final embedding = Float32List(flat.length);
    for (var i = 0; i < flat.length; i++) {
      embedding[i] = flat[i];
    }

    // L2-normalise so cosine similarity == dot product.
    var norm = 0.0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm > 1e-6) {
      for (var i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }
    return embedding;
  }
}
