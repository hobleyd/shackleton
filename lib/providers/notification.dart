import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'error.g.dart';

@Riverpod(keepAlive: true)
class Error extends _$Error {
  @override
  List<String> build() {
    return [];
  }

  void setError(String error, { int lifeSpan = -1 }) {
    List<String> errors = List.from(state);
    errors.insert(0, error);

    state = errors;
  }
}


