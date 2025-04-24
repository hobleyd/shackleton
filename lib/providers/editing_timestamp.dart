import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/file_of_interest.dart';

part 'editing_timestamp.g.dart';

@Riverpod(keepAlive: true)
class EditingTimestamp extends _$EditingTimestamp {
  @override
  int build(FileOfInterest entity) {
    return -1;
  }

  void setLastClickTimestamp(int timestamp) {
    state = timestamp;
  }
}
