import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../application/use_cases/delete_files_use_case.dart';
import '../domain/repositories/i_file_tags_repository.dart';
import '../interfaces/file_events_callback.dart';
import '../models/file_of_interest.dart';
import '../repositories/file_tags_repository.dart';

part 'file_events.g.dart';

@Riverpod(keepAlive: true)
class FileEvents extends _$FileEvents {
  late final DeleteFilesUseCase _deleteUseCase;

  @override
  List<FileEventsCallback> build() {
    ref.keepAlive();
    final IFileTagsRepository tags = ref.read(fileTagsRepositoryProvider.notifier);
    _deleteUseCase = DeleteFilesUseCase(tagsRepository: tags);
    return [];
  }

  void delete(FileOfInterest entity, {required bool deleteEntity}) {
    if (entity.isDirectory && entity.exists) {
      for (final file in (entity.entity as Directory).listSync()) {
        delete(FileOfInterest(entity: file), deleteEntity: deleteEntity);
      }
    }

    for (final callback in state) {
      callback.remove(entity);
    }

    if (entity.exists && deleteEntity) {
      _deleteUseCase.execute(entity);
    }
  }

  void deleteAll(Set<FileOfInterest> entities) {
    for (final e in entities) {
      delete(e, deleteEntity: true);
    }
  }

  void register(FileEventsCallback callback) {
    if (!state.contains(callback)) {
      state = [...state, callback];
    }
  }
}
