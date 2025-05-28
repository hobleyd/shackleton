import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/error.dart';

part 'notification.g.dart';

@Riverpod(keepAlive: true)
class Notification extends _$Notification {
  @override
  List<Error> build() {
    return [];
  }

  void clear() {
    state = [];
  }

  void removeError(Error e) {
    List<Error> errors = List.from(state);
    errors.remove(e);

    state = errors;
  }

  Error setError(String error, { int lifespan = -1 }) {
    Error e = Error(message: error, lifespan: lifespan);
    List<Error> errors = List.from(state);
    errors.insert(0, e);

    if (lifespan > 0) {
      Future.delayed(Duration(milliseconds: 1000 * lifespan), () {
        removeError(e);
      });
    }

    state = errors;

    return e;
  }
}


