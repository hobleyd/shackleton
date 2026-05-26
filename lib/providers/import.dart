import 'package:path/path.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/use_cases/import_files_use_case.dart';
import '../misc/utils.dart';
import '../models/file_of_interest.dart';
import '../models/import_entity.dart';
import '../providers/exif_tool_service_provider.dart';

part 'import.g.dart';

@riverpod
class Import extends _$Import {
  late final ImportFilesUseCase _useCase;
  List<ImportEntity> _importEntities = [];

  @override
  Future<List<ImportEntity>> build(Set<FileOfInterest> entities) async {
    ref.keepAlive();
    _useCase = ImportFilesUseCase(
      exifService: ref.read(exifToolServiceProvider),
      libraryPath: join(getHomeFolder(), 'Pictures'),
    );
    _importEntities = await _useCase.processEntities(entities);
    return _importEntities;
  }

  void replace(ImportEntity entity, ImportEntity replacement) async {
    _importEntities[_importEntities.indexOf(entity)] = replacement;
    state = await AsyncValue.guard(() async => _importEntities);
  }
}
