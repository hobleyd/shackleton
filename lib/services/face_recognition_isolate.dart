/// Long-lived worker isolate for face detection and embedding.
///
/// This isolate owns the ONNX sessions so all CPU-heavy work (image decode,
/// resize, preprocessing, inference, postprocessing) happens off the main
/// thread. Communication is via SendPort/ReceivePort message passing.
///
/// Protocol (main → worker):
///   spawn args: [detModelPath, recModelPath, SendPort mainPort]
///   worker → main: SendPort commandPort   (step 1 – worker's command inbox)
///   worker → main: true                   (step 2 – models loaded, ready)
///   main → worker: \[String imagePath, SendPort replyPort\]  (detect request)
///   worker → replyPort: List of FaceDetection | String error
///   main → worker: null                   (dispose / shut down)

library;

import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:onnxruntime/onnxruntime.dart';

import '../domain/services/i_face_recognition_service.dart';

// ── Constants (duplicated here so the isolate is self-contained) ──────────────

const int _detInputSize = 640;
const int _faceSize = 112;
const double _detThreshold = 0.5;
const double _nmsThreshold = 0.4;
const List<int> _strides = [8, 16, 32];
const int _numAnchors = 2;

const List<List<double>> _arcfaceTemplate = [
  [38.2946, 51.6963],
  [73.5318, 51.5014],
  [56.0252, 71.7366],
  [41.5493, 92.3655],
  [70.7299, 92.2041],
];

// ── Entry point ───────────────────────────────────────────────────────────────

/// Top-level entry point — must be a top-level function for Isolate.spawn.
/// [args] = [String detModelPath, String recModelPath, SendPort mainPort]
void faceRecognitionIsolateEntry(List<Object?> args) async {
  final detModelPath = args[0] as String;
  final recModelPath = args[1] as String;
  final mainPort = args[2] as SendPort;

  final commandPort = ReceivePort();
  mainPort.send(commandPort.sendPort); // step 1

  final sessionOpts = OrtSessionOptions();
  final detSession = OrtSession.fromFile(File(detModelPath), sessionOpts);
  final recSession = OrtSession.fromFile(File(recModelPath), sessionOpts);
  final detRunOpts = OrtRunOptions();
  final recRunOpts = OrtRunOptions();

  mainPort.send(true); // step 2: ready

  await for (final msg in commandPort) {
    if (msg == null) break;

    final cmd = msg as List<Object?>;
    final imagePath = cmd[0] as String;
    final replyPort = cmd[1] as SendPort;

    try {
      final detections = await _detectFaces(
        imagePath, detSession, recSession, detRunOpts, recRunOpts,
      );
      replyPort.send(detections);
    } catch (e, st) {
      replyPort.send('$e\n$st');
    }
  }

  detSession.release();
  recSession.release();
  detRunOpts.release();
  recRunOpts.release();
  commandPort.close();
}

// ── Core detection logic ──────────────────────────────────────────────────────

Future<List<FaceDetection>> _detectFaces(
  String imagePath,
  OrtSession detSession,
  OrtSession recSession,
  OrtRunOptions detRunOpts,
  OrtRunOptions recRunOpts,
) async {
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
  final detInputName = detSession.inputNames[0];
  final outputs = await (detSession.runAsync(detRunOpts, {detInputName: inputTensor}) ??
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
    final embedding = await _computeEmbedding(aligned, recSession, recRunOpts);
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

// ── Image preprocessing ───────────────────────────────────────────────────────

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

// ── SCRFD post-processing ─────────────────────────────────────────────────────

typedef _Candidate = ({List<double> bbox, double score, List<List<double>> landmarks});

List<_Candidate> _postprocessSCRFD(
  List<OrtValue?> outputs,
  double scaleX,
  double scaleY,
) {
  final fmc = _strides.length;
  final results = <_Candidate>[];

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
            for (var lk = 0; lk < 5; lk++)
              [
                (cx + kpsFlat[kBase + lk * 2] * stride) * scaleX,
                (cy + kpsFlat[kBase + lk * 2 + 1] * stride) * scaleY,
              ]
          ];

          results.add((bbox: [x1, y1, x2, y2], score: score, landmarks: landmarks));
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

// ── NMS ───────────────────────────────────────────────────────────────────────

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

// ── Face alignment ────────────────────────────────────────────────────────────

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

// ── ArcFace embedding ─────────────────────────────────────────────────────────

Future<Float32List> _computeEmbedding(
  img.Image faceImage,
  OrtSession recSession,
  OrtRunOptions recRunOpts,
) async {
  final data = _preprocessImage(faceImage, _faceSize, _faceSize);
  final inputTensor = OrtValueTensor.createTensorWithDataList(
    data,
    [1, 3, _faceSize, _faceSize],
  );
  final recInputName = recSession.inputNames[0];
  final outputs = await (recSession.runAsync(recRunOpts, {recInputName: inputTensor}) ??
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
