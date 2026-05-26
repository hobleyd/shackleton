import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/services/i_exif_tool_service.dart';
import '../services/exif_tool_service.dart';

final exifToolServiceProvider = Provider<IExifToolService>(
  (_) => ExifToolService(),
);
