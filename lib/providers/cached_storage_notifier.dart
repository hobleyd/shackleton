import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/cached_storage.dart';

part 'cached_storage_notifier.g.dart';

@riverpod
CachedStorage cachedStorage(CachedStorageRef ref) {
    return CachedStorage();
}
