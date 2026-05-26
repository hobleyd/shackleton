import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart';

import '../../domain/services/i_exif_tool_service.dart';
import '../../misc/utils.dart';
import '../../models/file_of_interest.dart';
import '../../models/import_entity.dart';

class ImportFilesUseCase {
  final IExifToolService _exifService;
  final String libraryPath;

  ImportFilesUseCase({
    required IExifToolService exifService,
    required this.libraryPath,
  }) : _exifService = exifService;

  Future<List<ImportEntity>> processEntities(Set<FileOfInterest> entities) async {
    final files = <ImportEntity>[];
    for (final entity in entities) {
      files.addAll(await _processEntity(entity));
    }
    return files;
  }

  Future<List<ImportEntity>> _processEntity(FileOfInterest entity) async {
    if (entity.isDirectory) {
      final results = <ImportEntity>[];
      for (final e in (entity.entity as Directory).listSync()) {
        results.addAll(await _processEntity(FileOfInterest(entity: e)));
      }
      return results;
    }

    if (!entity.isFile) return [];
    return [await processFile(entity)];

  }

  Future<ImportEntity> processFile(FileOfInterest entity) async {
    final base = ImportEntity(fileToImport: entity);

    if (!base.willImport || !entity.exists) {
      return base.copyWith(willImport: false, hasConflict: true);
    }

    if (_exifService.findExifTool() == null) {
      return base.copyWith(willImport: false, hasConflict: true);
    }

    final creationDate = await _exifService.readCreationDate(entity.path) ?? DateTime.now();
    final year = DateFormat('yyyy').format(creationDate);
    final month = DateFormat('MM - MMMM').format(creationDate);
    final destination = join(libraryPath, year, month, entity.name);

    return _validateDestination(base.copyWith(renamedFile: destination));
  }

  Future<ImportEntity> _validateDestination(ImportEntity importEntity) async {
    final dest = getEntity(importEntity.renamedFile);
    final hasConflict = dest.existsSync() &&
        await importEntity.fileToImport.different(FileOfInterest(entity: dest));
    return importEntity.copyWith(
      hasConflict: hasConflict,
      willImport: !hasConflict,
    );
  }
}
