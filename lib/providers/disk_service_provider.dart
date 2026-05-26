import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/i_disk_service.dart';
import '../services/disk_service.dart';

final diskServiceProvider = Provider<IDiskService>(
  (_) => DiskService(),
);
