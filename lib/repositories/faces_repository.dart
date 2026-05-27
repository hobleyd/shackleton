import 'dart:io';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../database/app_database.dart';
import '../domain/repositories/i_faces_repository.dart';
import '../domain/services/i_face_recognition_service.dart';
import '../models/face_identity.dart';
import '../models/file_of_interest.dart';
import '../providers/face_recognition_service_provider.dart';

part 'faces_repository.g.dart';

@Riverpod(keepAlive: true)
class FacesRepository extends _$FacesRepository implements IFacesRepository {
  late final AppDatabase _db;
  late final IFaceRecognitionService _faceService;

  @override
  Future<void> build() async {
    _db = ref.read(appDatabaseProvider.notifier);
    _faceService = ref.read(faceRecognitionServiceProvider);
  }

  // ── Identities ─────────────────────────────────────────────────────────────

  @override
  Future<FaceIdentity?> getIdentityByName(String name) async {
    final rows = await _db.query('face_identities',
        columns: ['id', 'name', 'embedding'], where: 'name = ?', whereArgs: [name]);
    if (rows.isEmpty) return null;
    return FaceIdentity.fromMap(rows.first);
  }

  @override
  Future<FaceIdentity> upsertIdentity(String name, Float32List embedding) async {
    final bytes = Uint8List.view(embedding.buffer);
    await _db.insert(
      'face_identities',
      {'name': name, 'embedding': bytes},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    final rows = await _db.query('face_identities',
        columns: ['id', 'name', 'embedding'], where: 'name = ?', whereArgs: [name]);
    return FaceIdentity.fromMap(rows.first);
  }

  @override
  Future<List<FaceIdentity>> getAllIdentities() async {
    final rows = await _db.query('face_identities',
        columns: ['id', 'name', 'embedding'], orderBy: 'name');
    return rows.map(FaceIdentity.fromMap).toList();
  }

  // ── Face storage ───────────────────────────────────────────────────────────

  @override
  Future<void> storeFaces(String path, List<FaceDetection> detections) async {
    await _db.transaction((txn) async {
      final fileRows = await txn.query('files',
          columns: ['id'], where: 'path = ?', whereArgs: [path]);
      final fileId = fileRows.isNotEmpty
          ? fileRows.first['id'] as int
          : await txn.insert('files', {'path': path});

      // Clear any previous face detections for this file.
      await txn.delete('file_faces', where: 'file_id = ?', whereArgs: [fileId]);

      for (var i = 0; i < detections.length; i++) {
        final d = detections[i];
        await txn.insert('file_faces', {
          'file_id': fileId,
          'face_index': i,
          'embedding': Uint8List.view(d.embedding.buffer),
          'bbox_x': d.bboxX,
          'bbox_y': d.bboxY,
          'bbox_w': d.bboxW,
          'bbox_h': d.bboxH,
          'confidence': d.confidence,
        });
      }
    });
  }

  @override
  Future<void> markScanned(String path) async {
    await _db.transaction((txn) async {
      final fileRows = await txn.query('files',
          columns: ['id'], where: 'path = ?', whereArgs: [path]);
      final fileId = fileRows.isNotEmpty
          ? fileRows.first['id'] as int
          : await txn.insert('files', {'path': path});
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await txn.insert(
        'file_face_scan_status',
        {'file_id': fileId, 'scanned_at': ts},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<bool> hasBeenScanned(String path) async {
    final rows = await _db.rawQuery(
      'select 1 from file_face_scan_status '
      'where file_id = (select id from files where path = ?) limit 1',
      [path],
    );
    return rows.isNotEmpty;
  }

  // ── Similarity search ──────────────────────────────────────────────────────

  @override
  Future<List<({FileOfInterest file, double similarity})>> findFilesMatchingIdentity(
    FaceIdentity identity,
    double threshold, {
    String? excludeTagName,
  }) async {
    // Load all embeddings from the DB in one query.
    final rows = await _db.rawQuery(
      'select f.path, ff.embedding '
      'from file_faces ff '
      'join files f on f.id = ff.file_id',
      [],
    );

    final matched = <({FileOfInterest file, double similarity})>[];
    final seen = <String>{};

    for (final row in rows) {
      final filePath = row['path'] as String;
      if (!File(filePath).existsSync()) continue;
      if (seen.contains(filePath)) continue; // only need one matching face per file

      final embeddingBytes = row['embedding'] as Uint8List;
      final faceEmbedding = Float32List.sublistView(embeddingBytes);
      final sim = _faceService.cosineSimilarity(identity.embedding, faceEmbedding);

      if (sim >= threshold) {
        seen.add(filePath);
        matched.add((
          file: FileOfInterest(entity: File(filePath)),
          similarity: sim,
        ));
      }
    }

    // Filter out files already tagged with the person's name.
    if (excludeTagName != null && excludeTagName.isNotEmpty) {
      final taggedPaths = await _getPathsWithTag(excludeTagName);
      matched.removeWhere((m) => taggedPaths.contains(m.file.path));
    }

    matched.sort((a, b) => b.similarity.compareTo(a.similarity));
    return matched;
  }

  Future<Set<String>> _getPathsWithTag(String tagName) async {
    final rows = await _db.rawQuery(
      'select f.path from files f '
      'join file_tags ft on ft.fileId = f.id '
      'join tags t on t.id = ft.tagId '
      'where t.tag = ?',
      [tagName],
    );
    return {for (final r in rows) r['path'] as String};
  }
}
