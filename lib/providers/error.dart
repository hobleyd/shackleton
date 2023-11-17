import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'error.g.dart';

@Riverpod(keepAlive: true)
class Error extends _$Error {
  @override
  String build() {
    return "";
  }

  void setError(String error) {
    state = error;
  }
}


